package Gitpan::Role::HasUA;

use perl5i::2;
use Method::Signatures;

use Mouse::Role;
use Gitpan::Types;

has ua =>
  is            => 'rw',
  isa           => 'LWP::UserAgent',
  lazy          => 1,
  builder       => 'default_ua';

# Everybody share one index object.
method default_ua {
    require LWP::UserAgent;
    state $lwp = LWP::UserAgent->new;
    return $lwp;
}
