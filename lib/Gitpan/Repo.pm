package Gitpan::Repo;

# Handles the coordination of the Git and Gitpan repositories

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;

use Gitpan::Github;
use Gitpan::Git;

with 'Gitpan::Role::HasConfig',
     'Gitpan::Role::CanBackoff';

haz distname =>
  is            => 'ro',
  isa           => DistName,
  required      => 1;

with 'Gitpan::Role::CanDistLog';

haz repo_dir =>
  isa           => Path,
  lazy          => 1,
  default       => method {
      $self->config->gitpan_repo_dir->child($self->distname_path);
  };

haz github =>
  is            => 'ro',
  isa           => InstanceOf['Gitpan::Github'],
  lazy          => 1,
  predicate     => 'has_github',
  clearer       => 'clear_github',
  default       => method {
      return Gitpan::Github->new(
          repo => $self->distname
      );
  };

haz git =>
  is            => 'rw',
  isa           => InstanceOf["Gitpan::Git"],
  lazy          => 1,
  predicate     => 'has_git',
  clearer       => 'clear_git',
  default       => method {
      return Gitpan::Git->new_or_init(
          repo_dir => $self->repo_dir,
          distname => $self->distname,
      );
  };

haz is_prepared_for_commits =>
  is            => 'rw',
  isa           => Bool,
  default       => 0;

haz is_prepared_for_push =>
  is            => 'rw',
  isa           => Bool,
  default       => 0;


method default_success_check($return?) {
    return $return ? 1 : 0;
}


method delete_repo( Bool :$wait = 0 ) {
    $self->dist_log("Deleting repository @{[$self->distname]}");

    $self->github->delete_repo_if_exists;

    # The ->git accessor will recreate the Github repo and clone it.
    # Avoid that.
    if( $self->have_git_repo ) {
        my $git = Gitpan::Git->new(
            repo_dir => $self->repo_dir,
            distname => $self->distname,
        );
        $git->delete_repo;
    }

    # ->git may contain a now bogus object, kill it so the Repo object
    # can get a fresh git repo and still be useful.
    $self->clear_git;

    $self->wait_until_deleted if $wait;

    return 1;
}


method wait_until_deleted() {
    my $ok = $self->do_with_backoff(
        code => sub { !$self->github->exists_on_github }
    );
    croak "Repo was not deleted in time" unless $ok;

    return 1;
}


method wait_until_created() {
    my $ok = $self->do_with_backoff(
        code => sub { $self->github->exists_on_github }
    );
    croak "Repo was not created in time" unless $ok;

    return 1;
}


method prepare_for_push() {
    return 1 if $self->is_prepared_for_push;

    $self->dist_log("Repo prepare_for_push");

    my $github = $self->github;

    if( $self->have_github_repo ) {
        # We have a Git repo, update it from Github
        if( $self->have_git_repo ) {
            my $git = Gitpan::Git->new(
                repo_dir    => $self->repo_dir,
                distname    => $self->distname
            );
            $self->git($git);

            $git->change_remote( origin => $self->github->remote );
            $git->pull( "ff_only" => 1 );
        }
        # No local repo, clone Github
        else {
            my $git = Gitpan::Git->clone(
                repo_dir    => $self->repo_dir,
                distname    => $self->distname,
                url         => $self->github->remote
            );
            $self->git($git);
        }
    }
    # No Github repo, make one.
    else {
        $github->create_repo;

        # Init a repo, or use an existing one,
        # and set the remote to the new Github repo.
        # Save the cost of cloning nothing.
        my $git = Gitpan::Git->new_or_init(
            repo_dir    => $self->repo_dir,
            distname    => $self->distname
        );
        $git->change_remote( origin => $self->github->remote );
        $self->git($git);
    }

    $self->is_prepared_for_commits(1);
    $self->is_prepared_for_push(1);

    return 1;
}


method prepare_for_commits() {
    return 1 if $self->is_prepared_for_commits;

    $self->dist_log("Repo prepare_for_commits");

    # There's a Git repo
    if( $self->have_git_repo ) {
        my $git = Gitpan::Git->new(
            repo_dir    => $self->repo_dir,
            distname    => $self->distname
        );
        $git->prepare_for_commits;
        $self->git($git);

        if( $self->have_github_repo ) {
            $git->change_remote( origin => $self->github->remote );
            $git->pull( "ff_only" => 1 );
            $self->is_prepared_for_push(1);
        }
    }
    # There's no git repo, but there is a Github repo
    elsif( $self->have_github_repo ) {
        my $git = Gitpan::Git->clone(
            repo_dir    => $self->repo_dir,
            distname    => $self->distname,
            url         => $self->github->remote
        );
        $self->git($git);
        $self->is_prepared_for_push(1);
    }
    # There's no Git or Gitpan repo
    else {
        my $git = Gitpan::Git->init(
            repo_dir    => $self->repo_dir,
            distname    => $self->distname
        );
        $self->git($git);
    }

    $self->is_prepared_for_commits(1);

    return 1;
}


method have_git_repo() {
    return -d $self->repo_dir->child(".git");
}


method have_github_repo() {
    return $self->github->exists_on_github;
}


method releases() {
    return [] if !$self->have_git_repo;
    return $self->git->releases;
}


method are_git_and_github_on_the_same_commit() {
    my $branch_info = $self->github->branch_info;
    return $self->git->head->target->id eq $branch_info->{commit}{sha};
}

method push(...) {
    $self->prepare_for_push;
    return $self->git->push(@_);
}

method pull(...) {
    return $self->git->pull(@_);
}


method import_release(
    Gitpan::Release $release,
    Bool :$push  = 0,
    Bool :$clean = 0
) {
    # Capture and log warnings, prepending with the specific release.
    local $SIG{__WARN__} = sub {
        $self->main_log("@{[$release->short_path]}: $_") for @_;
        $self->dist_log(join "", @_);
    };

    $self->main_log( "Importing @{[$release->short_path]}" );
    $self->dist_log( "Importing @{[$release->short_path]}" );

    $self->prepare_for_commits;

    my $git = $self->git;

    $release->get;

    $git->rm_all;

    $release->move($git->repo_dir);

    $git->add_all;

    $git->commit_release($release);

    $self->push if $push;
    $git->clean if $clean;

    return;
}


method import_releases(
    ArrayRef[Gitpan::Release] :$releases,
    CodeRef     :$before_import                 = sub {},
    CodeRef     :$after_import                  = sub {},
    Bool        :$push                          = 1,
    Bool        :$clean                         = 1
) {
    if( !@$releases ) {
        $self->main_log( "Nothing to import for @{[$self->distname]}" );
        return;
    }

    # Capture and log warnings.
    local $SIG{__WARN__} = sub {
        $self->main_log("@{[$self->distname]}: $_") for @_;
        $self->dist_log(join "", @_);
    };

    # Check if a repository with the same name, but different casing, already
    # exists on Github.
    my $github_repo = $self->github->get_repo_info;
    if( $github_repo && $github_repo->{name} ne $self->github->repo_name_on_github ) {
        $self->main_log("Error: distribution $github_repo->{name} already exists, @{[$self->distname]} would clash.");
        return 0;
    }

    my $versions = join ", ", map { $_->version } @$releases;
    $self->main_log( "Importing @{[$self->distname]} versions $versions" );
    $self->dist_log( "Importing $versions" );

    for my $release (@$releases) {
        eval {
            $self->$before_import($release);
            $self->import_release($release);
            $self->$after_import($release);
            1;
        } or do {
            $self->main_log("Error importing @{[$release->short_path]}: $@");
            $self->dist_log("$@");
        };
    }

    $self->push         if $push;
    $self->git->clean   if $clean;

    return 1;
}
