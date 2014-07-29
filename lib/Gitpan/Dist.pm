package Gitpan::Dist;

use Moo;
use Gitpan::MooTypes;

use perl5i::2;
use Method::Signatures;

with 'Gitpan::Role::HasBackpanIndex';

has name =>
  is            => 'ro',
  isa           => DistName,
  required      => 1;

has repo =>
  is            => 'ro',
  isa           => InstanceOf['Gitpan::Repo'],
  lazy          => 1,
  default       => method {
      require Gitpan::Repo;
      return Gitpan::Repo->new(
          distname => $self->name
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
