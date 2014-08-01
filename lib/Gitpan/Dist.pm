package Gitpan::Dist;

use Gitpan::OO;
use Gitpan::Types;

use perl5i::2;
use Path::Tiny;
use Method::Signatures;

with 'Gitpan::Role::HasBackpanIndex';

haz name =>
  is            => 'ro',
  isa           => DistName,
  required      => 1;

haz repo =>
  is            => 'ro',
  isa           => InstanceOf['Gitpan::Repo'],
  lazy          => 1,
  default       => method {
      require Gitpan::Repo;
      return Gitpan::Repo->new(
          distname => $self->name,
          ($ENV{GITPAN_TEST} ? (directory => Path::Tiny->tempdir) : ()),
      );
  };

method backpan_dist {
    return $self->backpan_index->dist($self->name);
}

method backpan_releases {
    return $self->backpan_dist->releases->search(
        # Ignore ppm releases, we only care about source releases.
        { path => { 'not like', '%.ppm' } },
        { order_by => { -asc => "date" } } );
}

method release(Str :$version) {
    require Gitpan::Release;
    return Gitpan::Release->new(
        distname        => $self->name,
        version         => $version
    );
}

method releases_to_import() {
    my $backpan_releases = $self->backpan_releases;
    my @backpan_versions = map { $_->version } $backpan_releases->all;

    my $gitpan_releases = $self->repo->git->releases;

    return @backpan_versions->diff($gitpan_releases);
}
