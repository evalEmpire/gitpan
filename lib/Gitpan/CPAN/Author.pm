package Gitpan::CPAN::Author;

use Gitpan::perl5i;
use Gitpan::OO;
use Gitpan::Types;

haz name =>
  is            => 'ro',
  isa           => Str,
  required      => 1;

haz email =>
  is            => 'ro',
  isa           => Str,
  default       => '';

haz url =>
  is            => 'ro',
  isa           => URI,
  default       => '';

haz cpanid =>
  is            => 'ro',
  isa           => Str,
  required      => 1;
