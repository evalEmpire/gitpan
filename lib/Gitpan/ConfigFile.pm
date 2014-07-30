package Gitpan::ConfigFile;

use Gitpan::OO;
use Gitpan::Types;
use perl5i::2;
use Method::Signatures;
use Gitpan::Config;

use YAML::XS qw(LoadFile);

haz config_filename =>
  is            => 'ro',
  isa           => Str,
  default       => ".gitpan";

# Search from first to last.
haz search_dirs =>
  is            => 'ro',
  isa           => ArrayRef[Path],
  default       => method {
      return [
          map { $_->path } grep { defined && length }
            $ENV{GITPAN_CONFIG_DIR}, ".", $ENV{HOME}
      ];
  };

haz config_file =>
  is            => 'ro',
  isa           => Maybe[Path],
  lazy          => 1,
  builder       => 'search_for_config_file';

haz config =>
  is            => 'ro',
  isa           => InstanceOf['Gitpan::Config'],
  lazy          => 1,
  builder       => 'read_config_file';

haz is_test     =>
  is            => 'ro',
  isa           => Bool,
  default       => 0;

haz use_overlays =>
  is            => 'ro',
  isa           => ArrayRef,
  lazy          => 1,
  default       => method {
      return $self->is_test ? ["test"] : [];
  };


=head1 NAME

Gitpan::ConfigFile - Configuration file for Gitpan

=head1 SYNOPSIS

    # A ConfigFile object should generally not be created directly,
    # but via Gitpan::Role::HasConfig like so.
    my $config = $object->config;

    # Get some data out of the config.
    my $github_token = $config->config->{github}{token};

=head1 DESCRIPTION

This is an object to access the Gitpan configuration.

By default, the configuration file is stored in F<.gitpan>.  It is
looked for in GITPAN_CONFIG_DIR (environment variable), the current
working directory or the home directory in that order.

The format of the config file is YAML.

=head2 Overlays

Sometimes you want to change some config values in certain situations,
such as when testing, without duplicating everything.  For this there
are "overlays".  Values in an overlay will replace the normal values.

Currently the only recognized overlay is "test" used while testing
Gitpan.

=head1 ENVIRONMENT

=head3 GITPAN_CONFIG_DIR

If set, it will look for the configuration file in this directory first.

=head1 SEE ALSO

L<Gitpan::Role::HasConfig>

=cut


method search_for_config_file {
    my $filename = $self->config_filename;
    my $dirs = $self->search_dirs;

    if( my $dir = $dirs->first(sub{ -e $_->path->child($filename) }) ) {
        return $dir->path->child($filename);
    }
    else {
        return;
    }
}

method read_config_file {
    my $config_data;
    if( my $file = $self->config_file ) {
        $config_data = $self->_apply_overlays( LoadFile( $file ) );
    }
    else {
        $config_data = {};
    }

    return Gitpan::Config->new($config_data);
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
