package Gitpan::Repo;

# Handles the coordination of the Git and Gitpan repositories

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;

with 'Gitpan::Role::HasConfig';

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
      require Gitpan::Github;
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
      my $github = $self->github;
      $github->maybe_create;

      require Gitpan::Git;
      return Gitpan::Git->new_or_clone(
          repo_dir => $self->repo_dir,
          url      => $github->remote,
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


method delete_repo {
    $self->dist_log("Deleting repository");

    $self->github->delete_repo_if_exists;

    # The ->git accessor will recreate the Github repo and clone it.
    # Avoid that.
    if( $self->have_git_repo ) {
        require Gitpan::Git;
        my $git = Gitpan::Git->new(
            repo_dir => $self->repo_dir,
            distname => $self->distname,
        );
        $git->delete_repo;
    }

    # ->git may contain a now bogus object, kill it so the Repo object
    # can get a fresh git repo and still be useful.
    $self->clear_git;

    return;
}


method prepare_for_push() {
    return 1 if $self->is_prepared_for_push;

    require Gitpan::Git;

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

    require Gitpan::Git;

    # There's a Git repo
    if( $self->have_git_repo ) {
        my $git = Gitpan::Git->new(
            repo_dir    => $self->repo_dir,
            distname    => $self->distname
        );
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


method are_git_and_github_on_the_same_commit() {
    my $branch_info = $self->github->branch_info;
    return $self->git->head->target->id eq $branch_info->{commit}{sha};
}
