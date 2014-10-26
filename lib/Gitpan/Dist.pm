package Gitpan::Dist;

use Gitpan::perl5i;

use Gitpan::Release;
use Gitpan::OO;
use Gitpan::Types;

use Gitpan::Repo;

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

haz backpan_releases =>
  is            => 'ro',
  isa           => InstanceOf["DBIx::Class::ResultSet"],
  lazy          => 1,
  default       => method {
      return scalar $self->backpan_dist->releases->search(
          # Ignore ppm releases, we only care about source releases.
          { path => { 'not like', '%.ppm' } },
          # Import releases by date, don't try to figure out versions.
          { order_by => { -asc => "date" } }
      );
  };

haz repo =>
  is            => 'ro',
  isa           => InstanceOf['Gitpan::Repo'],
  handles       => [qw(
      git
      has_git
      clear_git

      github
      has_github
      clear_github

      repo_dir
      delete_repo
  )],
  default       => method {
      return Gitpan::Repo->new(
          distname      => $self->name
      );
  };


method BUILDARGS($class: %args) {
    croak "name or backpan_dist required"
      unless $args{name} // $args{backpan_dist};

    return \%args;
}

method release_from_version(Str $version) {
    return Gitpan::Release->new(
        distname        => $self->name,
        version         => $version
    );
}

method release_from_backpan( BackPAN::Index::Release $backpan_release ) {
    return Gitpan::Release->new(
        backpan_release => $backpan_release
    );
}


method paths_to_import() {
    return [map { $_->short_path } @{$self->releases_to_import}];
}


method versions_to_import() {
    return [map { $_->version } @{$self->releases_to_import}];
}

method releases_to_import() {
    my $imported = $self->git->releases->as_hash;

    my $config = $self->config;

    my @releases;
    for my $bp_release ($self->backpan_releases->all) {
        next if $imported->{$bp_release->short_path};
        next if $config->skip_release($bp_release->short_path);

        push @releases, $self->release_from_backpan( $bp_release );
    }

    return \@releases;
}


method import_releases(
    ArrayRef[Gitpan::Release] :$releases,
    CodeRef     :$before_import                 = sub {},
    CodeRef     :$after_import                  = sub {},
    Bool        :$push                          = 1,
    Bool        :$clean                         = 1
) {
    # Capture and log warnings.
    local $SIG{__WARN__} = sub {
        $self->main_log("@{[$self->distname]}: $_") for @_;
        $self->dist_log(join "", @_);
    };

    # Do this here, not as a default, so we can catch warnings.
    $releases ||= $self->releases_to_import;
    if( !@$releases ) {
        $self->main_log( "Nothing to import for @{[$self->distname]}" );
        return;
    }

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

    $self->repo->push   if $push;
    $self->git->clean   if $clean;

    return 1;
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

    $self->repo->prepare_for_commits;

    my $git = $self->git;

    $release->get;

    $git->rm_all;

    $release->move($git->repo_dir);

    $git->add_all;

    $git->commit_release($release);

    $self->repo->push   if $push;
    $git->clean         if $clean;

    return;
}
