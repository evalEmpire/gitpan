package Gitpan::Release;

use Gitpan::OO;
use Gitpan::Types;
use perl5i::2;
use Method::Signatures;

with
  'Gitpan::Role::HasBackpanIndex',
  'Gitpan::Role::HasConfig',
  'Gitpan::Role::HasCPANAuthors',
  'Gitpan::Role::HasUA';

haz distname =>
  is            => 'ro',
  isa           => DistName,
  required      => 1;

haz version =>
  is            => 'ro',
  isa           => Str,
  required      => 1;

haz normalized_version =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      my $version = $self->version;

      $version =~ s{^\.}{0.};  # git does not like a leading . as a tag name
      $version =~ s{\.$}{};    # nor a trailing one

      return $version;
  };

haz short_path =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      return sprintf "%s/%s", $self->cpanid, $self->filename;
  };

haz backpan_release =>
  is            => 'ro',
  isa           => InstanceOf['BackPAN::Index::Release'],
  lazy          => 1,
  handles       => [qw(
      cpanid
      date
      distvname
      filename
      maturity
  )],
  default       => method {
      return $self->backpan_index
                  ->releases($self->distname)
                  ->single({ version => $self->version });
  };

haz url =>
  is            => 'ro',
  isa           => URI,
  lazy          => 1,
  default       => method {
      my $url = $self->config->backpan_url->clone;
      $url->append_path($self->path);

      return $url;
  };

haz backpan_file     =>
  is            => 'ro',
  isa           => InstanceOf['BackPAN::Index::File'],
  lazy          => 1,
  handles       => [qw(
      path
      size
  )],
  default       => method {
      $self->backpan_release->path;
  };

haz author =>
  is            => 'ro',
  isa           => InstanceOf['Parse::CPAN::Authors::Author'],
  lazy          => 1,
  default       => method {
      return $self->cpan_authors->author($self->cpanid);
  };

haz work_dir =>
  is            => 'ro',
  isa           => AbsPath,
  lazy          => 1,
  default       => method {
      require Path::Tiny;
      return Path::Tiny->tempdir;
  };

haz archive_file =>
  is            => 'ro',
  isa           => AbsPath,
  lazy          => 1,
  default       => method {
      return $self->work_dir->child( $self->filename );
  };

haz extract_dir =>
  isa           => AbsPath,
  clearer       => "_clear_extract_dir";

method get {
    my $res = $self->ua->get(
        $self->url,
        ":content_file" => $self->archive_file.""
    );

    croak "Get from @{[$self->url]} was not successful: ".$res->status_line
      unless $res->is_success;
    croak "File not fully retrieved" unless -s $self->archive_file == $self->size;

    return $res;
}

method extract {
    my $archive = $self->archive_file;
    my $dir     = $self->work_dir;

    croak "$archive does not exist, did you get it?" unless -e $archive;

    require Archive::Extract;
    my $ae = Archive::Extract->new( archive => $archive );
    $ae->extract( to => $dir ) or
      croak "Couldn't extract $archive to $dir: ". $ae->error;

    $self->extract_dir( $ae->extract_path );

    $self->fix_permissions;

    croak "Extraction directory does not exist" unless -e $self->extract_dir;

    return $self->extract_dir;
}

# Make sure the archive files are readable and the directories are traversable.
method fix_permissions {
    return unless -d $self->extract_dir;

    $self->extract_dir->chmod("u+rx");

    require File::Find;
    File::Find::find(sub {
        -d $_ ? $_->path->chmod("u+rx") : $_->path->chmod("u+r");
    }, $self->extract_dir);

    return;
}

method move(Path::Tiny $to) {
    croak "$to is not a directory" if !-d $to;

    $self->extract if !$self->extract_dir;
    my $from = $self->extract_dir;

    use File::Copy::Recursive ();
    File::Copy::Recursive::dirmove( $from, $to );

    # Have to re-extract
    $self->_clear_extract_dir;

    return;
}
