package Gitpan::Role::HasUA;

use Gitpan::perl5i;

use Moo::Role;
use Gitpan::Types;

has ua =>
  is            => 'rw',
  isa           => InstanceOf['LWP::UserAgent'],
  lazy          => 1,
  builder       => 'default_ua';

# Everybody share one index object.
method default_ua {
    require LWP::UserAgent;
    state $lwp = LWP::UserAgent->new;
    return $lwp;
}
