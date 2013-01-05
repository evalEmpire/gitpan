package Gitpan::Dist;

use Mouse;
use Gitpan::Types;

use perl5i::2;
use Method::Signatures;

with 'Gitpan::Role::HasBackpanIndex';

has name =>
  is            => 'ro',
  isa           => 'Gitpan::Distname',
  required      => 1;

has repo =>
  is            => 'ro',
  isa           => 'Gitpan::Repo',
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
