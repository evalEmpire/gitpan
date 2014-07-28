package Gitpan::Git;

use perl5i::2;
use Method::Signatures;

use Moo;
use Git::Repository qw(Log);
extends 'Git::Repository';
with "Gitpan::Role::CanBackoff";

use Gitpan::Types ":types";

my $Gitpan_Email = 'schwern+gitpan@pobox.com';
my $Gitpan_Name  = 'Gitpan';

method init( $class: Path::Tiny $repo_dir ) {
    $class->run( init => $repo_dir );
    return $class->SUPER::new(
        work_tree => $repo_dir,
        {
            env => {
                GIT_COMMITTER_EMAIL => $Gitpan_Email,
                GIT_COMMITTER_NAME  => $Gitpan_Name,
                GIT_AUTHOR_EMAIL    => $Gitpan_Email,
                GIT_AUTHOR_NAME     => $Gitpan_Name,
            }
        },
    );
}

method clean {
    $self->remove_sample_hooks;
    $self->garbage_collect;
}

method hooks_dir {
    return $self->git_dir->path->child("hooks");
}

method garbage_collect {
    $self->run("gc");
}

# These sample hook files take up a surprising amount of space
# over thousands of repos.
method remove_sample_hooks {
    my $hooks_dir = $self->hooks_dir;
    return unless -d $hooks_dir;

    for my $sample ([$hooks_dir->children]->grep(qr{\.sample$})) {
        $sample->remove or warn "Couldn't remove $sample";
    }

    return 1;
}

method remotes() {
    my @remotes = $self->run("remote", "-v");
    my %remotes;
    for my $remote (@remotes) {
        my($name, $url, $action) = $remote =~ m{^ (\S+) \s+ (.*?) \s+ \( (.*?) \) $}x;
        $remotes{$name}{$action} = $url;
    }

    return \%remotes;
}

method remote( Str $name, Str $action = "push" ) {
    return $self->remotes->{$name}{$action};
}

method change_remote( Str $name, Str $url ) {
    my $remotes = $self->remotes;

    if( $remotes->{$name} ) {
        $self->set_remote_url( $name, $url );
    }
    else {
        $self->add_remote( $name, $url );
    }
}

method set_remote_url( Str $name, Str $url ) {
    $self->run( remote => "set-url" => $name => $url );
}

method add_remote( Str $name, Str $url ) {
    $self->run( remote => add => $name => $url );
}

method default_success_check($return?) {
    return $return ? 1 : 0;
}

method push( Str $remote = "origin", Str $branch = "master" ) {
    # sometimes github doesn't have the repo ready immediately after create_repo
    # returns, so if push fails try it again.
    my $ok = $self->do_with_backoff(
        times => 3,
        code  => sub {
            eval { $self->run(push => $remote => $branch) } || return
        },
    );
    return unless $ok;

    $self->run( push => $remote => "--tags" );

    return 1;
}

method remove_working_copy {
    for my $child ( $self->work_tree->children ) {
        next if $child->is_dir and $child->basename eq '.git';
        $child->is_dir ? $child->remove_tree : $child->remove;
    }
}

method revision_exists(Str $revision) {
    my $rev = eval { $self->run("rev-parse", $revision) } || return 0;
    return 1;
}

method releases {
    return unless $self->revision_exists("HEAD");

    my @releases = map  { m{\bgit-cpan-version:\s*(\S+)}x; $1 }
                   grep /^\s*git-cpan-version:/,
                     $self->run(log => '--pretty=format:%b');
    return @releases;
}

method fixup_repository {
    # We do our work in cpan/master, it might not exist if this
    # repo was cloned from gitpan.
    if( !$self->revision_exists("cpan/master") and $self->revision_exists("master") ) {
        $self->run('branch', '-t', 'cpan/master', 'master');
    }
    return 1;
}

method last_commit {
    return eval { $self->run("rev-parse", "-q", "--verify", "cpan/master") };
}

method last_cpan_version {
    my $last_commit = $self->last_commit;
    return unless $last_commit;

    my $last = $self->run( log => '--pretty=format:%b', '-n', 1, $last_commit );
    $last =~ /git-cpan-module:\ (.*?) \s+ git-cpan-version:\ (.*?) \s*$/sx
      or croak "Couldn't parse git message:\n$last\n";

    return $2;
}

method work_tree {
    return $self->SUPER::work_tree->path;
}
