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
  handles       => [qw(
      is_empty
      head
      ignore
  )],
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
    Str        :$url!,
    HashRef    :$options = {},
    Str        :$distname!,
    Path::Tiny :$repo_dir
) {
    my $self = $class->new(
        distname => $distname,
        $repo_dir ? (repo_dir => $repo_dir) : ()
    );

    $self->dist_log( "git clone from $url in @{[$self->repo_dir]}" );

    # sometimes github doesn't have the repo ready immediately after create_repo
    # returns, so if push fails try it again.
    my $git;
    my $ok = $self->do_with_backoff(
        code  => sub {
            eval {
                $git = Git::Raw::Repository->clone(
                    $url, $self->repo_dir.'', $options
                );
            };
            $self->dist_log( "Clone failed: $@" ) if !$git;

            return $git;
        },
    );
    croak "Could not clone from $url: $@" unless $ok;

    $self->git_raw($git);
    $self->init_git_config;

    return $self;
}


method new_or_action( $class: ... ) {
    my %params = @_;
    my $action = delete $params{action};

    my $repo_dir = $params{repo_dir};

    # There's a directory but no repository, get rid of it.
    $repo_dir->remove_tree({ safe => 0 })
      if -d $repo_dir && !-d $repo_dir->child(".git");

    # There's no repository.
    return Gitpan::Git->$action(%params)
      if !-d $repo_dir;

    # There is a repository.
    my $git = Gitpan::Git->new(
        repo_dir => $repo_dir,
        distname => $params{distname}
    );

    return $git;
}


method new_or_init( $class: ... ) {
    return $class->new_or_action( action => "init", @_ );
}

method new_or_clone( $class: ... ) {
    my %args = @_;

    my $git = $class->new_or_action( action => "clone", %args );

    # If there's an existing repository, turn it into an effective clone.
    $git->change_remote( origin => $args{url} );
    $git->pull( "ff_only" => 1 );

    return $git;
}


method init_git_config() {
    my $config = $self->config;
    my $git_config = $self->git_raw->config;

    $git_config->str( "user.name",  $config->committer_name );
    $git_config->str( "user.email", $config->committer_email );

    return;
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
    $self->dist_log("git gc");
    $self->run("gc", "--quiet");
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
    return '' unless $remote;
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

method push(
    Str  :$remote  //= "origin",
    Str  :$branch  //= "master"
) {
    $self->dist_log( "Pushing to $remote $branch" );

    # sometimes github doesn't have the repo ready immediately after create_repo
    # returns, so if push fails try it again.
    my $ok = $self->do_with_backoff(
        code  => sub {
            my $ret = eval {
                $self->run(push => "-q" => $remote => $branch, {
                    fatal => "!0"
                });
                1;
            };
            if( !$ret ) {
                $self->dist_log( "Push failed: $@" );
            }

            return $ret;
        },
    );
    croak "Could not push to $remote $branch: $@" unless $ok;

    eval {
        $self->run( push => "-q" => "-f" => $remote => $branch => "--tags", {
            fatal => "!0"
        });
        1;
    } or croak "Could not push tags to $remote $branch: $@";

    return 1;
}

method pull(
    Str  :$remote  //= "origin",
    Str  :$branch  //= "master",
    Bool :$ff_only //= 0
) {
    $self->dist_log( "Pulling from $remote $branch" );

    my @options = ("-q");
    @options->push("--ff-only") if $ff_only;

    my $ok = $self->do_with_backoff(
        code  => sub {
            my $ret = eval {
                $self->run(pull => @options => $remote => $branch);
                1;
            };
            if( !$ret ) {
                $self->dist_log( "Pull failed: $@" );
                croak $@ if $@ =~ /Not possible to fast-forward/;
            }

            return $ret;
        },
    );
    croak "Could not pull from $remote $branch: $@" unless $ok;

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

method prepare_for_commits {
    $self->dist_log( "Git prepare_for_commits" );

    # Without any commits, we need different techniques.
    return $self->prepare_for_import_empty_repo if $self->is_empty;

    # Remove all untracked files
    $self->run("clean", "-dxf");

    # Make sure we're in the right branch and clean up
    # the staging area and working tree
    $self->run("reset", "-q", "--hard", "HEAD");
    $self->checkout("master", force => 1);

    return;
}


method checkout(
    Str         $branch_name,
    Bool        :$force = 0,
) {
    my @run_args = ("checkout", "-q");
    @run_args->push("-f") if $force;

    $self->run(@run_args, $branch_name);

    return;
}


method prepare_for_import_empty_repo {
    # Unstage and delete everything.
    $self->run("rm", "--ignore-unmatch", "-rf", ".");

    # Remove all untracked files
    $self->run("clean", "-dxf");

    return;
}

method revision_exists(Str $revision) {
    my $git_raw = $self->git_raw;

    my $branch = Git::Raw::Branch->lookup( $git_raw, $revision, 1 );
    return $branch if $branch;

    my $tag = Git::Raw::Reference->lookup( "refs/tags/$revision", $git_raw );
    return $tag if $tag;

    # This doesn't like getting "invalid characters"
    my $commit = eval { Git::Raw::Commit->lookup( $git_raw, $revision ) };
    return $commit if $commit;

    return;
}


method current_branch {
    return if $self->is_empty;
    return $self->head->shorthand;
}


method commit_release(Gitpan::Release $release) {
    my $author = $release->author;

    $self->dist_log( "Committing @{[ $release->short_path ]}" );

    my $commit_message = <<"MESSAGE";
Import of @{[ $release->short_path ]} from CPAN.

gitpan-cpan-distribution: @{[ $release->distname ]}
gitpan-cpan-version:      @{[ $release->version ]}
gitpan-cpan-path:         @{[ $release->short_path ]}
gitpan-cpan-author:       @{[ $author->cpanid ]}
gitpan-cpan-maturity:     @{[ $release->maturity ]}

MESSAGE

    $self->commit(
        author          => $author,
        message         => $commit_message,
        release         => $release
    );

    $self->tag_release($release);

    return;
}

method commit(
    Gitpan::CPAN::Author :$author,
    Gitpan::Release      :$release,
    Str                  :$message!
) {
    my $repo = $self->git_raw;

    my $committer_sig = Git::Raw::Signature->default( $self->git_raw );

    my $author_sig;
    if( $author ) {
        $author_sig = Git::Raw::Signature->new(
            Encode::encode_utf8($author->name || $author->cpanid),
            Encode::encode_utf8($author->email),
            $release ? $release->date : 'now',
            0
        );
    }
    else {
        $author_sig = $committer_sig;
    }

    my @parents = $repo->is_empty ? () : ($repo->head->target);

    # Refresh our index from disk in case someone else added
    $repo->index->read;

    return $repo->commit(
        Encode::encode_utf8($message),
        $author_sig,
        $committer_sig,
        \@parents,
        $repo->index->write_tree,
    );
}

method add(@files) {
    $self->dist_log( "git add @files" );

    croak "No files given to add" unless @files;

    my $index = $self->git_raw->index;
    $index->add($_) for @files;
    $index->write;

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
    if( defined $release->version and length $release->version )
    {
        my $safe_cpan_version   = $self->ref_safe_version($release->version);
        my $safe_gitpan_version = $self->ref_safe_version($release->gitpan_version);

        $self->tag_if_not_tagged(
            $self->config->cpan_release_tag_prefix.$safe_cpan_version
        );
        $self->tag_if_not_tagged(
            $self->config->gitpan_release_tag_prefix.$safe_gitpan_version
        );
    }

    # Tag the CPAN Path
    $self->tag($self->config->cpan_path_tag_prefix.$release->short_path);

    # Update the latest stable/alpha release tag.
    $self->tag( $self->maturity2tag( $release->maturity ), force => 1 );

    # Update the latest release by this author.
    $self->tag( $release->author->cpanid,                  force => 1 );

    return;
}


method tag_if_not_tagged(Str $tag) {
    if( $self->revision_exists($tag) ) {
        $self->dist_log("$tag already exists");
        return;
    }

    $self->tag($tag);

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


method list_tags( Regexp :$pattern? ) {
    my @tags = map { $_->isa("Git::Raw::Tag") ? $_->name : $_->shorthand }
                   $self->git_raw->tags;

    @tags = grep m{$pattern}, @tags if $pattern;

    return \@tags;
}


method releases {
    return [] if $self->is_empty;

    return $self->cpan_paths;
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


method get_tag( Str $name ) {
    return Git::Raw::Reference->lookup("refs/tags/$name", $self->git_raw);
}


method list_tags_no_prefix( Str $prefix ) {
    my $pattern = qr{^\Q$prefix};

    return [map { s{$pattern}{}; $_ }
               @{ $self->list_tags( pattern => $pattern ) }];
}
