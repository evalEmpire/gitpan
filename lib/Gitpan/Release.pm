package Gitpan::Release;

use Gitpan::perl5i;
use Gitpan::OO;
use Gitpan::Types;

with
  'Gitpan::Role::HasBackpanIndex',
  'Gitpan::Role::HasConfig',
  'Gitpan::Role::HasCPANAuthors',
  'Gitpan::Role::HasUA';

haz distname =>
  is            => 'ro',
  isa           => DistName,
  default       => method {
      return $self->backpan_release->dist->name;
  };

with 'Gitpan::Role::CanDistLog';

haz version =>
  is            => 'ro',
  isa           => Str,
  default       => method {
      return $self->backpan_release->version;
  };

haz gitpan_version =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      my $version = $self->version;
      $version =~ s{^v}{};

      return $version;
  };


require BackPAN::Index::Release;
# Fuck Type short_path() into BackPAN::Index::Release.
*BackPAN::Index::Release::short_path = method {
    return sprintf("%s/%s", $self->cpanid, $self->filename);
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
      short_path
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
  isa           => InstanceOf['Gitpan::CPAN::Author'],
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


method BUILDARGS($class: %args) {
    croak "distname & version or backpan_release required"
      unless ($args{distname} && defined $args{version}) || $args{backpan_release};

    return \%args;
}


method get {
    my $url = $self->url;

    $self->dist_log( "Getting $url" );

    my $res = $self->ua->get(
        $url,
        ":content_file" => $self->archive_file.""
    );

    croak "Get from $url was not successful: ".$res->status_line
      unless $res->is_success;
    croak "File not fully retrieved" unless -s $self->archive_file == $self->size;

    return $res;
}

method extract {
    my $archive = $self->archive_file;
    my $dir     = $self->work_dir;

    $self->dist_log( "Extracting $archive to $dir" );

    croak "$archive does not exist, did you get it?" unless -e $archive;

    require Archive::Extract;
    local $Archive::Extract::PREFER_BIN = 1;
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

method move(
    Path::Tiny $to,
    Bool :$clean_for_import = 1
) {
    croak "$to is not a directory" if !-d $to;

    $self->extract if !$self->extract_dir;
    my $from = $self->extract_dir;

    $self->clean_extraction_for_import if $clean_for_import;

    $self->dist_log( "Moving from $from to $to" );

    use File::Copy::Recursive ();
    File::Copy::Recursive::dirmove( $from, $to );

    # Have to re-extract
    $self->_clear_extract_dir;

    return;
}


method clean_extraction_for_import() {
    my $dir = $self->extract_dir;

    # A .git directory in the tarball will interfere with
    # our own git repository.
    $dir->child(".git")->remove_tree({ safe => 0 });

    return;
}
