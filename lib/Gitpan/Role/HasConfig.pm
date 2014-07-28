package Gitpan::Role::HasConfig;

use perl5i::2;
use Method::Signatures;

use Moo::Role;
use Gitpan::MooTypes qw(:types);

use Gitpan::ConfigFile;
use Gitpan::Config;

my $Config;

has config =>
  is            => 'ro',
  isa           => InstanceOf["Gitpan::Config"],
  lazy          => 1,
  default       => method {
      return $Config //= Gitpan::ConfigFile->new->config;
  };


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

The configuration is shared by all.

=head2 Accessors

=head3 config

Returns the shared L<Gitpan::Config> object.

Normally there is no need to set the config.

=head1 SEE ALSO

L<Gitpan::ConfigFile>

=cut
