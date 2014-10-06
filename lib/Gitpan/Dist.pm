package Gitpan::Dist;

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;

with 'Gitpan::Role::HasBackpanIndex';

use overload
  q[""]     => method { return $self->name },
  fallback  => 1;

haz name =>
  is            => 'ro',
  isa           => DistName,
  default       => method {
      $self->backpan_dist->name;
  };

*distname = \&name;

with 'Gitpan::Role::CanDistLog';

haz backpan_dist =>
  is            => 'ro',
  isa           => InstanceOf['BackPAN::Index::Dist'],
  lazy          => 1,
  default       => method {
      return $self->backpan_index->dist($self->name);
  };


haz repo_dir =>
  isa           => Path,
  lazy          => 1,
  default       => method {
      $self->config->gitpan_repo_dir->child($self->distname_path);
  };

haz git     =>
  isa       => InstanceOf["Gitpan::Git"],
  required  => 1,
  lazy      => 1,
  predicate => 'has_git',
  clearer   => 'clear_git',
  default   => method {
      my $github = $self->github;
      $github->maybe_create;

      require Gitpan::Git;
      return Gitpan::Git->new_or_clone(
          repo_dir => $self->repo_dir,
          url      => $github->remote,
          distname => $self->name,
      );
  };

haz github  =>
  isa       => HashRef|InstanceOf['Gitpan::Github'],
  lazy      => 1,
  predicate => 'has_github',
  coerce    => 0,
  trigger   => method($new, $old?) {
      return $new if $new->isa("Gitpan::Github");
      my $gh = $self->_new_github($new);
      $self->github( $gh );
  },
  default   => method {
      return $self->_new_github;
  };

method BUILDARGS($class: %args) {
    croak "name or backpan_dist required"
      unless $args{name} // $args{backpan_dist};

    return \%args;
}

method _new_github(HashRef $args = {}) {
    require Gitpan::Github;
    return Gitpan::Github->new(
        repo      => $self->name,
        %$args,
    );
}

method exists_on_github() {
    # Optimization, asking github is expensive
    return 1 if $self->git->remote("origin") =~ /github.com/;
    return $self->github->exists_on_github();
}

method backpan_releases {
    return $self->backpan_dist->releases->search(
        # Ignore ppm releases, we only care about source releases.
        { path => { 'not like', '%.ppm' } },
        { order_by => { -asc => "date" } } );
}

method release_from_version(Str $version) {
    require Gitpan::Release;
    return Gitpan::Release->new(
        distname        => $self->name,
        version         => $version
    );
}

method release_from_backpan( BackPAN::Index::Release $backpan_release ) {
    require Gitpan::Release;
    return Gitpan::Release->new(
        backpan_release => $backpan_release
    );
}


method versions_to_import() {
    my $backpan_releases = $self->backpan_releases;
    my @backpan_versions = map { $_->version } $backpan_releases->all;

    my $gitpan_releases = $self->git->releases;

    return scalar @backpan_versions->diff($gitpan_releases);
}

method releases_to_import() {
    my @releases;
    for my $version ($self->versions_to_import->flatten) {
        push @releases, $self->release_from_version( $version );
    }

    return \@releases;
}

method delete_repo {
    $self->dist_log("Deleting repository for @{[$self->name]}");

    $self->github->delete_repo_if_exists;

    # The ->git accessor will recreate the Github repo and clone it.
    # Avoid that.
    require Gitpan::Git;
    my $git = Gitpan::Git->init(
        repo_dir => $self->repo_dir,
        distname => $self->name,
    );
    $git->delete_repo;

    # ->git may contain a now bogus object, kill it so the Dist object 
    # can get a fresh git repo and still be useful.
    $self->clear_git;

    return;
}


method import_releases(
    ArrayRef[Gitpan::Release] :$releases        = $self->releases_to_import,
    CodeRef     :$before_import                 = sub {},
    CodeRef     :$after_import                  = sub {},
    Bool        :$push                          = 1
) {
    my $versions = join ", ", map { $_->version } @$releases;
    $self->main_log( "Importing @{[$self->distname]} versions $versions" );
    $self->dist_log( "Importing $versions" );

    $self->git->prepare_for_import;

    for my $release (@$releases) {
        eval {
            $self->$before_import($release);
            $self->import_release($release, push => 0);
            $self->$after_import($release);
            1;
        } or do {
            my $error = $@;
            $self->main_log("Error importing @{[$release->short_path]}: $error");
            $self->dist_log($error);
            return 0;
        };
    }

    $self->git->push if $push;

    return 1;
}


method import_release(
    Gitpan::Release $release,
    Bool :$push = 1
) {
    $self->main_log( "Importing @{[$release->short_path]}" );
    $self->dist_log( "Importing @{[$release->short_path]}" );

    my $git = $self->git;

    $release->get;

    $git->rm_all;

    $release->move($git->repo_dir);

    $git->add_all;

    $git->commit_release($release);

    $git->push if $push;
}
