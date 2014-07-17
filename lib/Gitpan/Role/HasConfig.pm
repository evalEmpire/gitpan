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


=head1 NAME

Gitpan::Role::HasConfig - Per object access to the config

=head1 SYNOPSIS

    {
        package Some::Class;
        use Mouse;
        with 'Gitpan::Role::HasConfig';
    }

    my $obj = Some::Class->new;
    my $config = $obj->config;

=head1 DESCRIPTION

With this role your object will have access to the Gitpan configuration.

=head2 Accessors

=head3 config

Access to the config object.

Normally there is no need to set the config.

=head3 config_class

What sub-class of L<Gitpan::Config> should be used to instanciate the
config object.

Defaults to L<Gitpan::Config>.

=head1 SEE ALSO

L<Gitpan::Config>

=cut
