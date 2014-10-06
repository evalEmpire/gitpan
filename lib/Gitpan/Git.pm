package Gitpan::Git;

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;
use Git::Repository qw(Log Status);
use Git::Raw;
with "Gitpan::Role::CanBackoff",
     "Gitpan::Role::HasConfig";

haz distname =>
  is            => 'ro',
  isa           => DistName;

with "Gitpan::Role::CanDistLog";

haz repo_dir =>
  is            => 'ro',
  isa           => AbsPath,
  lazy          => 1,
  default       => method {
      require Path::Tiny;
      return Path::Tiny->tempdir;
  };

haz git_repo =>
  isa           => InstanceOf["Git::Repository"],
  handles       => [qw(
      run
      log
      status
      git_dir
  )],
  lazy          => 1,
  default       => method {
      return Git::Repository->new(
          work_tree => $self->repo_dir.''
      );
  };

haz git_raw =>
  isa           => InstanceOf["Git::Raw::Repository"],
  lazy          => 1,
  default       => method {
      return Git::Raw::Repository->open( $self->repo_dir.'' );
  };

method init($class: %args) {
    my $self = $class->new(%args);

    $self->dist_log( "git init in @{[$self->repo_dir]}" );

    my $git = Git::Raw::Repository->init( $self->repo_dir.'', 0 );
    $self->git_raw($git);
    $self->init_git_config;

    return $self;
}

# $url should be a URI|Path but Method::Signatures does not understand
# Type::Tiny (yet)
method clone(
    $class:
    Str :$url!,
    HashRef :$options = {},
    Str :$distname!,
    Path::Tiny :$repo_dir
) {
    my $self = $class->new(
        distname        => $distname,
        $repo_dir ? (repo_dir        => $repo_dir) : ()
    );

    $self->dist_log( "git clone from $url in @{[$self->repo_dir]}" );

    my $git = Git::Raw::Repository->clone( $url, $self->repo_dir.'', $options );
    $self->git_raw($git);
    $self->init_git_config;

    return $self;
}


method new_or_clone( %args ) {
    my $repo_dir = $args{repo_dir};

    # There's a directory but no repository, get rid of it.
    $repo_dir->remove_tree({ safe => 0 })
      if -d $repo_dir && !-d $repo_dir->child(".git");

    # There's no repository.
    return Gitpan::Git->clone(%args)
      if !-d $repo_dir;

    # There is a repository.
    my $git = Gitpan::Git->new(
        repo_dir => $repo_dir,
        distname => $args{distname}
    );
    $git->fixup_repo(
        url       => $args{url}
    );

    return $git;
}

method init_git_config() {
    my $config = $self->config;
    my $git_config = $self->git_raw->config;

    $git_config->str( "user.name",  $config->committer_name );
    $git_config->str( "user.email", $config->committer_email );

    return;
}


# Run quiet, run deep
method run_quiet(...) {
    my $opts = ref $_[-1] eq 'HASH' ? pop @_ : {};
    $opts->{quiet} = 1;

    return $self->run(@_, $opts);
}


method delete_repo {
    $self->dist_log("Deleting git repository @{[$self->repo_dir]}");
    $self->repo_dir->remove_tree({ safe => 0 });
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
    my %remotes = map { ($_->name => $_) } $self->git_raw->remotes;
    return \%remotes;
}

method remote( Str $name, Str $action = "push" ) {
    my $remote = $self->remotes->{$name};
    return $action eq "push" ? $remote->pushurl || $remote->url : $remote->url;
}

method change_remote( Str $name, Str $url ) {
    my $remotes = $self->remotes;

    if( $remotes->{$name} ) {
        return $self->set_remote_url( $name, $url );
    }
    else {
        return $self->add_remote( $name, $url );
    }
}

method set_remote_url( Str $name, Str $url ) {
    $self->dist_log( "Changing remote $name to $url" );

    my $remote = $self->remotes->{$name};
    $remote->url($url);
    $remote->pushurl($url);

    return $remote;
}

method add_remote( Str $name, Str $url ) {
    $self->dist_log( "Adding new remote $name to $url" );

    return Git::Raw::Remote->create( $self->git_raw, $name, $url );
}

method default_success_check($return?) {
    return $return ? 1 : 0;
}

method push( Str $remote //= "origin", Str $branch //= "master" ) {
    $self->dist_log( "Pushing to $remote $branch" );

    # sometimes github doesn't have the repo ready immediately after create_repo
    # returns, so if push fails try it again.
    my $ok = $self->do_with_backoff(
        times => 3,
        code  => sub {
            eval { $self->run_quiet(push => $remote => $branch); 1 };
        },
        check => method($return) {
            $self->dist_log( "Push failed" ) if !$return;
            return $return;
        }
    );
    die "Could not push: $@" unless $ok;

    $self->run_quiet( push => $remote => $branch => "--tags" );

    return 1;
}

method pull( Str $remote //= "origin", Str $branch //= "master" ) {
    $self->dist_log( "Pulling from $remote $branch" );

    my $ok = $self->do_with_backoff(
        times => 3,
        code  => sub {
            eval { $self->run_quiet(pull => $remote => $branch) } || return
        },
        check => method($return) {
            $self->dist_log( "Pull failed" ) if !$return;
            return $return;
        }
    );
    return $ok;
}

method rm_all {
    $self->dist_log( "git rm_all" );

    $self->remove_working_copy;

    my $index = $self->git_raw->index;
    $index->update_all({
        paths   => ['*']
    });
    $index->write;

    return;
}

method add_all {
    $self->dist_log( "git add_all" );

    my $index = $self->git_raw->index;
    $index->add_all({
        paths => ['*'],
        flags => { force => 1 }
    });
    $index->write;

    return;
}

method remove_working_copy {
    $self->dist_log( "git remove_working_copy" );

    for my $child ( $self->repo_dir->children ) {
        next if $child->is_dir and $child->basename eq '.git';
        $child->is_dir ? $child->remove_tree({safe => 0}) : $child->remove;
    }
}

method prepare_for_import {
    $self->dist_log( "git prepare_for_import" );

    # Without any commits, we need different techniques.
    return $self->prepare_for_import_empty_repo if !$self->revision_exists("HEAD");

    # Remove all untracked files
    $self->run("clean", "-dxf");

    # Make sure we're in the right branch and clean up
    # the staging area and working tree
    $self->run_quiet("reset", "--hard", "HEAD");
    $self->run_quiet("checkout", "-f", "master");

    return;
}


method fixup_repo( Str :$url! ) {
    $self->prepare_for_import;
    $self->change_remote( origin => $url );
    $self->pull;
}


method prepare_for_import_empty_repo {
    # Unstage and delete everything.
    $self->run("rm", "--ignore-unmatch", "-rf", ".");

    # Remove all untracked files
    $self->run("clean", "-dxf");

    return;
}

method revision_exists(Str $revision) {
    my $rev = eval { $self->run("rev-parse", $revision) } || return 0;
    return 1;
}


method current_branch {
    return eval { $self->run("rev-parse", "--abbrev-ref", "HEAD") } || undef;
}


method releases {
    return [] unless $self->revision_exists("HEAD");

    my $tag_prefix = $self->config->cpan_path_tag_prefix;
    return [map { s{^$tag_prefix}{}; $_ } $self->run(tag => '-l', "$tag_prefix*")];
}

method commit_release(Gitpan::Release $release) {
    my $author = $release->author;

    $self->dist_log( "Committing @{[ $release->short_path ]}" );

    my $commit_message = <<"MESSAGE";
Import of @{[ $author->cpanid ]}/@{[ $release->distvname ]} from CPAN.

gitpan-cpan-distribution: @{[ $release->distname ]}
gitpan-cpan-version:      @{[ $release->version ]}
gitpan-cpan-path:         @{[ $release->short_path ]}
gitpan-cpan-author:       @{[ $author->cpanid ]}
gitpan-cpan-maturity:     @{[ $release->maturity ]}

MESSAGE

    $self->run(
        "commit", "-m" => $commit_message,
        {
            env => {
                GIT_AUTHOR_DATE         => $release->date,
                GIT_AUTHOR_NAME         => $author->name || $author->cpanid,
                GIT_AUTHOR_EMAIL        => $author->email,
            },
        },
    );

    $self->tag_release($release);

    return;
}

# Some special handling when making versions tag safe.
method ref_safe_version(Str $version) {
    # Specifically change .1 into 0.1
    $version =~ s{^\.}{0.};

    return $version;
}

# See git-check-ref-format(1)
method make_ref_safe(Str $ref, :$substitution = "-") {
    # 6. They cannot begin or end with a slash / or contain multiple consecutive
    #    slashes.
    my @parts = grep { length } split m{/+}, $ref;

    for my $part (@parts) {
        # 1. no slash-separated component can begin with a dot .
        $part =~ s{^\.}{$substitution};

        # 1. or end with the sequence .lock
        $part =~ s{\.lock$}{$substitution};
    }

    $ref = join "/", @parts;

    # 3. They cannot have two consecutive dots
    $ref =~ s{\.{2,}}{\.}g;

    # 8. They cannot contain a sequence @{
    $ref =~ s{\@\{}{$substitution};

    # 4. They cannot have ASCII control characters (i.e. bytes whose values
    #    are lower than \040, or \177 DEL), space, tilde ~, caret ^, or
    #    colon : anywhere.
    # 5. They cannot have question-mark ?, asterisk *, or open bracket [ anywhere
    # 9. They cannot be the single character @
    # 10. They cannot contain a \
    $ref =~ s{[ [:cntrl:] [:space:] \~ \^ \: \? \* \[ \@ \\ ]+}{$substitution}gx;

    # 7. They cannot end with a dot
    $ref =~ s{\.$}{$substitution}g;

    return $ref;
}


method tag_release(Gitpan::Release $release) {
    $self->dist_log( "Tagging @{[ $release->short_path ]}" );

    # Special case for making versions safe
    # Some releases have no version.  They don't get a version tag.
    if( defined $release->version and length $release->version ) {
        my $safe_cpan_version   = $self->ref_safe_version($release->version);
        my $safe_gitpan_version = $self->ref_safe_version($release->gitpan_version);

        $self->tag($self->config->cpan_release_tag_prefix.$safe_cpan_version);
        $self->tag($self->config->gitpan_release_tag_prefix.$safe_gitpan_version);
    }

    # Tag the CPAN Path
    $self->tag($self->config->cpan_path_tag_prefix.$release->short_path);

    # Update the latest stable/alpha release tag.
    $self->tag( $self->maturity2tag( $release->maturity ), force => 1 );

    # Update the latest release by this author.
    $self->tag( $release->author->cpanid,                  force => 1 );

    return;
}


# BackPAN::Index (via CPAN::DistnameInfo) has its own names for
# the maturity of a release which differ from CPAN conventions.
method maturity2tag( Str $maturity ) {
    state $maturity2tag = {
        released        => "stable",
        developer       => "alpha"
    };

    return $maturity2tag->{$maturity} || $maturity;
}


method tag(Str $name, Bool :$force = 0) {
    my $git  = $self->git_raw;

    my $head = $git->head;

    my $safe_name = $self->make_ref_safe($name);

    return Git::Raw::Reference->create(
        "refs/tags/$safe_name", $git, $head->target, $force
    );
}


method list_tags( ArrayRef :$patterns = [] ) {
    return $self->run("tag", "-l", @$patterns);
}


method cpan_versions() {
    return $self->list_tags_no_prefix( $self->config->cpan_release_tag_prefix );
}


method cpan_paths() {
    return $self->list_tags_no_prefix( $self->config->cpan_path_tag_prefix );
}


method gitpan_versions() {
    return $self->list_tags_no_prefix( $self->config->gitpan_release_tag_prefix );
}


method list_tags_no_prefix( Str $prefix ) {
    return map { s{^\Q$prefix}{}; $_ } $self->list_tags( patterns => ["$prefix*"]);
}
