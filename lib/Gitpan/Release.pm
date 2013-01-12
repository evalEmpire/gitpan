package Gitpan::Release;

use Mouse;
use Gitpan::Types;
use perl5i::2;
use Method::Signatures;

use Path::Class ();

with
  'Gitpan::Role::HasBackpanIndex',
  'Gitpan::Role::HasCPANPLUS',
  'Gitpan::Role::HasUA';

has distname =>
  is            => 'ro',
  isa           => 'Gitpan::Distname',
  required      => 1;

has version =>
  is            => 'ro',
  isa           => 'Str',
  required      => 1;

has backpan_release =>
  is            => 'ro',
  isa           => 'BackPAN::Index::Release',
  lazy          => 1,
  handles       => [qw(
      cpanid
      date
      distvname
      filename
      maturity
  )],
  default       => method {
      return $self->backpan_index->releases($self->distname)->single({ version => $self->version });
  };

has backpan_file     =>
  is            => 'ro',
  isa           => 'BackPAN::Index::File',
  lazy          => 1,
  handles       => [qw(
      path
      size
      url
  )],
  default       => method {
      $self->backpan_release->path;
  };

has author =>
  is            => 'ro',
  isa           => 'CPANPLUS::Module::Author',
  lazy          => 1,
  default       => method {
      my $cpanid = $self->cpanid;
      return $self->cpanplus->author_tree->{$cpanid};
  };

has work_dir =>
  is            => 'ro',
  isa           => 'File::Temp::Dir',
  lazy          => 1,
  default       => method {
      require File::Temp;
      return File::Temp->newdir;
  };

has archive_file =>
  is            => 'ro',
  isa           => 'Path::Class::File',
  lazy          => 1,
  default       => method {
      return Path::Class::File->new( $self->work_dir, $self->filename );
  };

has extract_dir =>
  is            => 'rw',
  isa           => 'Path::Class::Dir',
  coerce        => 1;

method get {
    my $res = $self->ua->get(
        $self->url,
        ":content_file" => $self->archive_file.""
    );

    croak "File not fully retrieved" unless -s $self->archive_file == $self->size;

    return $res;
}

method extract {
    my $archive = $self->archive_file;
    my $dir     = $self->work_dir;

    croak "$archive does not exist, did you get it?" unless -e $archive;

    require Archive::Extract;
    my $ae = Archive::Extract->new( archive => $archive );
    croak "Couldn't extract $archive to $dir because ". $ae->error
      unless $ae->extract( to => $self->work_dir );

    $self->extract_dir( $ae->extract_path );

    return $self->extract_dir;
}
