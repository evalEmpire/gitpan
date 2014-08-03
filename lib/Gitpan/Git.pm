package Gitpan::Git;

use perl5i::2;
use Method::Signatures;

use Gitpan::OO;
use Git::Repository qw(Log);
extends 'Git::Repository';
with "Gitpan::Role::CanBackoff",
     "Gitpan::Role::HasConfig";

use Gitpan::Types;

method init( $class: Path::Tiny :$repo_dir = Path::Tiny->tempdir ) {
    $class->run( init => $repo_dir );

    return $class->_new_git($repo_dir);
}

# $url should be a URI|Path but Method::Signatures does not understand
# Type::Tiny (yet)
method clone(
    $class:
    Str :$url,
    Path::Tiny :$repo_dir = Path::Tiny->tempdir,
    ArrayRef :$options = []
) {
    $class->run( clone => $url, $repo_dir, @$options, { quiet => 1 } );

    return $class->_new_git($repo_dir);
}

method delete_repo {
    my $work_tree = $self->work_tree;
    $work_tree->remove_tree;
}


haz '_store_work_tree';

method _new_git($class: Path::Tiny $repo_dir) {
    my $config = $class->config;

    my $self = $class->SUPER::new(
        work_tree => $repo_dir,
        {
            env => {
                GIT_COMMITTER_EMAIL => $config->committer_email,
                GIT_COMMITTER_NAME  => $config->committer_name,
                GIT_AUTHOR_EMAIL    => $config->committer_email,
                GIT_AUTHOR_NAME     => $config->committer_name,
            }
        },
    );

    # This is a hack to keep a temp directory from destroying itself when
    # Git::Repository stringifies the $repo_dir object.
    $self->_store_work_tree($repo_dir);

    return $self;
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

method push( Str $remote //= "origin", Str $branch //= "master" ) {
    # sometimes github doesn't have the repo ready immediately after create_repo
    # returns, so if push fails try it again.
    my $ok = $self->do_with_backoff(
        times => 3,
        code  => sub {
            eval { $self->run(push => $remote => $branch, { quiet => 1 }); 1 };
        },
    );
    die "Could not push: $@" unless $ok;

    $self->run( push => $remote => $branch => "--tags", { quiet => 1 } );

    return 1;
}

method pull( Str $remote //= "origin", Str $branch //= "master" ) {
    my $ok = $self->do_with_backoff(
        times => 3,
        code  => sub {
            eval { $self->run(pull => $remote => $branch, { quiet => 1 }) } || return
        },
    );
    return $ok;
}

method rm_all {
    $self->run( rm => "--ignore-unmatch", "-fr", "." );
    # Clean up empty directories.
    $self->remove_working_copy;

    return;
}

method add_all {
    $self->run( add => "." );

    return;
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
    return [] unless $self->revision_exists("HEAD");

    return [map { s{^version/}{}; $_ } $self->run(tag => '-l', 'version/*')];
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
