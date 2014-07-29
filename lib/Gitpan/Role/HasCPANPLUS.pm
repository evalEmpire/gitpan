package Gitpan::Role::HasCPANPLUS;

use perl5i::2;
use Method::Signatures;

use Moo::Role;
use Gitpan::Types;

has cpanplus =>
  is            => 'rw',
  isa           => InstanceOf['CPANPLUS::Backend'],
  lazy          => 1,
  builder       => 'default_cpanplus';

# Everybody share one index object.
method default_cpanplus {
    require CPANPLUS::Backend;
    state $cpanplus = CPANPLUS::Backend->new;
    return $cpanplus;
}
