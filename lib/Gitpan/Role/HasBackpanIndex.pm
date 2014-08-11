package Gitpan::Role::HasBackpanIndex;

use perl5i::2;
use Method::Signatures;

use Moo::Role;
use Gitpan::Types;

with "Gitpan::Role::HasConfig";

has backpan_index =>
  is            => 'rw',
  isa           => InstanceOf['BackPAN::Index'],
  lazy          => 1,
  builder       => "default_backpan_index";

# Everybody share one index object.
method default_backpan_index {
    require BackPAN::Index;
    state $index = BackPAN::Index->new(
        cache_ttl       => $self->config->backpan_cache_ttl,
    );
    return $index;
}
