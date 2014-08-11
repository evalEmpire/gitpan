package Gitpan::Github;

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;
extends 'Net::GitHub::V3';
with 'Gitpan::Role::HasConfig';

use Encode;

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

# Github doesn't like non alphanumerics as repository names.
method repo_name_on_github(Str $repo //= $self->repo) {
    $repo =~ s{[^a-z0-9-_]+}{-}ig;
    $repo =~ s{-+}{-}g;
    return $repo;
}

method exists_on_github( Str :$owner //= $self->owner, Str :$repo //= $self->repo ) {
    $repo = $self->repo_name_on_github($repo);

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
    :$repo      //= $self->repo,
    :$desc      //= "Read-only release history for $repo",
    :$homepage  //= "http://metacpan.org/release/$repo"
)
{
    return $self->repos->create({
        org             => $self->owner,
        name            => encode_utf8($repo),
        description     => encode_utf8($desc),
        homepage        => encode_utf8($homepage),
        has_issues      => 0,
        has_wiki        => 0,
    });
}

method maybe_create(
    :$repo              //= $self->repo,
    Str :$desc,
    Str :$homepage
)
{
    return $repo if $self->exists_on_github(repo => $repo);
    return $self->create_repo(
        repo        => $repo,
        desc        => $desc,
        homepage    => $homepage,
    );
}

method delete_repo_if_exists( Str :$repo //= $self->repo ) {
    return if !$self->exists_on_github( repo => $repo );
    return $self->delete_repo( repo => $repo );
}

method delete_repo( Str :$repo //= $self->repo ) {
    $repo = $self->repo_name_on_github($repo);

    return $self->repos->delete($self->owner, $repo);
}

method remote(
    Str :$token //= $self->access_token,
    Str :$owner //= $self->owner,
    Str :$repo  //= $self->repo,
    Str :$host  //= $self->remote_host,
) {
    $repo = $self->repo_name_on_github($repo);
    return qq[https://$token:\@$host/$owner/$repo.git];
}

method change_repo_info(%changes) {
    return 1 unless keys %changes;

    my $repo = $self->repo_name_on_github($self->repo);
    return $self->repos->get($self->owner, $repo)->update(
        \%changes,
    );
}
