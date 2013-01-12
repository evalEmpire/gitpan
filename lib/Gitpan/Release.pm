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

has unpack_dir =>
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
      return Path::Class::File->new( $self->unpack_dir, $self->filename );
  };

method get {
    my $res = $self->ua->get(
        $self->url,
        ":content_file" => $self->archive_file.""
    );

    croak "File not fully retrieved" unless -s $self->archive_file == $self->size;

    return $res;
}
