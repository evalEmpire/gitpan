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


method import_releases(...) {
    $self->repo->import_releases(
        releases => $self->releases_to_import,
        @_
    );
}
