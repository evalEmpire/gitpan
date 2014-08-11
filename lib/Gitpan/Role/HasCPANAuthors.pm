package Gitpan::Role::HasCPANAuthors;

use perl5i::2;
use Method::Signatures;

use Carp;
use Moo::Role;
use Gitpan::Types;

with "Gitpan::Role::HasUA",
     "Gitpan::Role::HasConfig";

has cpan_authors =>
  is            => 'rw',
  isa           => InstanceOf['Parse::CPAN::Authors'],
  lazy          => 1,
  default       => method {
      state $authors;
      return $authors if $authors;

      my $mailrc_url = $self->config->backpan_url->clone;

      my $path = $mailrc_url->path;
      $path .= '/' unless $path =~ m{/$};
      $path .= "authors/01mailrc.txt.gz";
      $mailrc_url->path($path);

      my $tempdir = Path::Tiny->tempdir;
      my $mailrc = $tempdir->child("01mailrc.txt.gz");
      my $res = $self->ua->get(
          $mailrc_url,
          ":content_file" => $mailrc.''
      );
      croak "Get from @{[$mailrc_url]} was not successful: ".$res->status_line
        unless $res->is_success;

      require Parse::CPAN::Authors;
      $authors = Parse::CPAN::Authors->new($mailrc.'');

      return $authors;
  };
