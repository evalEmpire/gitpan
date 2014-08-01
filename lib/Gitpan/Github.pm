package Gitpan::Github;

use Gitpan::OO;
use Gitpan::Types;
extends 'Net::GitHub::V3';
with 'Gitpan::Role::HasConfig';

use version; our $VERSION = qv("v2.0.0");

use perl5i::2;
use Method::Signatures;

haz "owner" =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      return $self->config->github_owner;
  };

haz '+access_token' =>
  lazy          => 1,
  default       => method {
      return $self->config->github_access_token;
  };

haz "remote_host" =>
  is            => 'rw',
  isa           => Str,
  lazy          => 1,
  default       => method {
      return $self->config->github_remote_host;
  };

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
        if( /^Not Found\b/ ) {
            return 0
        }
        else {
            croak "Error checking if a $owner/$repo exists: $_";
        }
    };

    return $repo_obj ? 1 : 0;
}

method create_repo(
    Str :$repo     //= $self->repo,
    Str :$desc     //= "Read-only release history for $repo",
    Str :$homepage //= "http://metacpan.org/release/$repo"
)
{
    return $self->repos->create({
        org             => $self->owner,
        name            => $repo,
        description     => $desc,
        homepage        => $homepage,
        has_issues      => 0,
        has_wiki        => 0,
    });
}

method maybe_create(
    Str :$repo //= $self->repo,
    Str :$desc,
    Str :$homepage
)
{
    return $repo if $self->exists_on_github();
    return $self->create_repo(
        repo        => $repo,
        desc        => $desc,
        homepage    => $homepage,
    );
}

method remote(
    Str :$token //= $self->access_token,
    Str :$owner //= $self->owner,
    Str :$repo  //= $self->repo,
    Str :$host  //= $self->remote_host,
) {
    return qq[https://$token:\@$host/$owner/$repo.git];
}

method change_repo_info(%changes) {
    return 1 unless keys %changes;

    return $self->repos->get($self->owner, $self->repo)->update(
        \%changes,
    );
}
