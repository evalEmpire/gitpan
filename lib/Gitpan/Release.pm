package Gitpan::Release;

use Mouse;
use Gitpan::Types;
use perl5i::2;
use Method::Signatures;

with
  'Gitpan::Role::HasBackpanIndex',
  'Gitpan::Role::HasCPANPLUS';

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
