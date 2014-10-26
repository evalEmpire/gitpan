package Gitpan::Role::HasCPANAuthors;

use Gitpan::perl5i;

use Carp;
use Moo::Role;
use Gitpan::Types;

use Gitpan::CPAN::Authors;

with "Gitpan::Role::HasUA",
     "Gitpan::Role::HasConfig";

has cpan_authors =>
  is            => 'rw',
  isa           => InstanceOf['Gitpan::CPAN::Authors'],
  lazy          => 1,
  builder       => 'build_cpan_authors';

method build_cpan_authors {
    state $authors;
    return $authors if $authors;

    my $authors_url = $self->config->backpan_url->clone;
    $authors_url->append_path("authors/02authors.txt.gz");

    my $authors_file = Path::Tiny->tempfile;
    my $res = $self->ua->get(
        $authors_url,
        ":content_file" => $authors_file.''
    );
    croak "Get from @{[$authors_url]} was not successful: ".$res->status_line
      unless $res->is_success;

    $authors = Gitpan::CPAN::Authors->new(
        file => $authors_file
    );

    return $authors;
}
