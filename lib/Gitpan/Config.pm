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
