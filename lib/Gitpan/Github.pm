package Gitpan::Github;

use Mouse;
extends 'Net::GitHub::V3';

use version; our $VERSION = qv("v2.0.0");

use perl5i::2;
use Method::Signatures;
use Path::Class;

has "owner" =>
  is            => 'ro',
  isa           => 'Str',
  default       => 'gitpan',
;

has "+access_token" =>
  default       => sub {
      return $ENV{GITPAN_GITHUB_ACCESS_TOKEN} ||
             # A read only token for testing
             "f58a7dfa0f749ccb521c8da38f9649e2eff2434f"
  };

has "remote_host" =>
  is        => 'rw',
  isa       => 'Str',
  default   => 'github.com';

method BUILD( HashRef $args ) {
    if( $self->owner && $self->repo ) {
        $self->set_default_user_repo($self->owner, $self->repo);
    }

    return $self;
}

method exists_on_github( Str :$owner //= $self->owner, Str :$repo //= $self->repo ) {
    my $repo_obj;
    try {
        $repo_obj = $self->repos->get($owner, $repo);
    }
    catch {
        when( /^Not Found\b/ ) {
            return 0
        }
        default {
            croak "Error checking if a $owner/$repo exists: $_";
        }
    };

    return $repo_obj ? 1 : 0;
}

method create_repo( Str :$repo?, Str :$desc, Str :$homepage ) {
    $repo //= $self->repo;

    return $self->repos->create(
        org             => $self->owner,
        name            => $repo,
        description     => $desc,
        homepage        => $homepage,
        has_issues      => 0,
        has_wiki        => 0,
    );
}

method maybe_create( Str :$repo?, Str :$desc, Str :$homepage ) {
    $repo //= $self->repo;

    return $repo if $self->exists_on_github();
    return $self->create_repo(
        repo        => $repo,
        desc        => $desc,
        homepage    => $homepage,
    );
}

method remote( Str :$owner //= $self->owner, Str :$repo //= $self->repo ) {
    return sprintf q[git@%s:%s/%s.git], $self->remote_host, $owner, $repo;
}

method change_repo_info(%changes) {
    return 1 unless keys %changes;

    return $self->repos->get($self->owner, $self->repo)->update(
        \%changes,
    );
}
