package Gitpan::Role::HasConfig;

use Mouse::Role;
use perl5i::2;
use Method::Signatures;

has config =>
  is            => 'ro',
  isa           => "Gitpan::Config",
  lazy          => 1,
  default       => method {
      my $config_class = $self->config_class;
      $config_class->require;
      return $config_class->new;
  };

has config_class =>
  is            => 'ro',
  isa           => 'Str',
  default       => "Gitpan::Config";
