package Gitpan::Config;

use Mouse;
use Gitpan::Types;
use perl5i::2;
use Method::Signatures;
use Path::Class;

use YAML::XS qw(LoadFile);

has config_filename =>
  is            => 'ro',
  isa           => 'Str',
  default       => ".gitpan";

# Search from first to last.
has search_dirs =>
  is            => 'ro',
  isa           => 'ArrayRef[Path::Class::Dir]',
  default       => method {
      return [dir("."), dir($ENV{HOME})]
  };

has config_file =>
  is            => 'ro',
  isa           => 'Maybe[Path::Class::File]',
  lazy          => 1,
  builder       => 'search_for_config_file';

has config =>
  is            => 'ro',
  isa           => 'HashRef',
  lazy          => 1,
  builder       => 'read_config_file';

has is_test     =>
  is            => 'ro',
  isa           => 'Bool',
  default       => 1;

has use_overlays =>
  is            => 'ro',
  isa           => 'ArrayRef',
  lazy          => 1,
  default       => method {
      return $self->is_test ? ["test"] : [];
  };


=head1 NAME

Gitpan::Config - Configuration object for gitpan

=head1 SYNOPSIS

    # A Config object should generally not be created directly,
    # but via Gitpan::Role::HasConfig like so.
    my $config = $object->config;

    # Get some data out of the config.
    my $github_token = $config->config->{github}{token};

=head1 DESCRIPTION

This is an object to access the Gitpan configuration.

By default, the configuration file is stored in F<.gitpan> in either
the current working directory or the home directory.

The format of the config file is YAML.

=head2 Overlays

Sometimes you want to change some config values in certain situations,
such as when testing, without duplicating everything.  For this there
are "overlays".  Values in an overlay will replace the normal values.

Currently the only recognized overlay is "test" used while testing
Gitpan.

=head1 SEE ALSO

L<Gitpan::Role::HasConfig>

=cut


method search_for_config_file {
    my $filename = $self->config_filename;
    my $dirs = $self->search_dirs;

    if( my $dir = $dirs->first(sub{ -e file($_, $filename) }) ) {
        return file($dir, $filename);
    }
    else {
        return;
    }
}

method read_config_file {
    if( my $file = $self->config_file ) {
        return $self->_apply_overlays( LoadFile( $file ) );
    }
    else {
        return {};
    }
}

method _apply_overlays( HashRef $config ) {
    # Don't want them in the final config.
    my $overlays = delete $config->{overlays};

    $self->use_overlays->foreach( func($key) {
        my $overlay = $overlays->{$key};
        return unless $overlay;

        $config = $config->merge($overlay);
    });

    return $config;
}
