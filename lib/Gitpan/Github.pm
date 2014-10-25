package Gitpan::Github;

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;
extends 'Net::GitHub::V3';
with 'Gitpan::Role::HasConfig', 'Gitpan::Role::CanBackoff';

use Encode;

method distname { return $self->repo }
with "Gitpan::Role::CanDistLog";

haz "repo" =>
  required      => 1;

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

# BUILD in Moo roles don't appear to stack nicely, so we
# go around it.
after BUILD => method(...) {
    if( $self->owner && $self->repo ) {
        $self->set_default_user_repo($self->owner, $self->repo);
    }

    return;
};

# Github doesn't like non alphanumerics as repository names.
# Dots seem ok.
method repo_name_on_github(Str $repo //= $self->repo) {
    $repo =~ s{[^a-z0-9-_.]+}{-}ig;
    return $repo;
}

method get_repo_info( Str :$owner //= $self->owner, Str :$repo //= $self->repo ) {
    my $repo_on_github = $self->repo_name_on_github($repo);

    $self->dist_log( "Getting Github repo info for $repo as $repo_on_github" );

    my $repo_obj;
    try {
        $repo_obj = $self->repos->get($owner, $repo_on_github);
    }
    catch {
        if( /^Not Found\b/ ) {
            return 0
        }
        else {
            croak "Error checking if a $owner/$repo_on_github exists: $_";
        }
    };

    return $repo_obj;
}

method exists_on_github( Str :$owner //= $self->owner, Str :$repo //= $self->repo ) {
    $self->dist_log( "Checking if $repo exists on Github" );

    return $self->get_repo_info( owner => $owner, repo => $repo) ? 1 : 0;
}

method create_repo(
    :$repo      //= $self->repo,
    :$desc      //= "Read-only release history for $repo",
    :$homepage  //= "http://metacpan.org/release/$repo"
)
{
    $self->dist_log( "Creating Github repo for $repo" );

    my $create_ret = $self->repos->create({
        org             => $self->owner,
        name            => encode_utf8($repo),
        description     => encode_utf8($desc),
        homepage        => encode_utf8($homepage),
        has_issues      => 0,
        has_wiki        => 0,
    });

    # Sometimes Github doesn't immediately create the repo, wait
    # until it exists.
    $self->do_with_backoff(
        code  => sub { $self->exists_on_github }
    );

    return $create_ret;
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

method default_success_check($return?) {
    return $return ? 1 : 0;
}

method delete_repo( Str :$repo //= $self->repo ) {
    my $repo_on_github = $self->repo_name_on_github($repo);

    $self->dist_log( "Deleting $repo on Github as $repo_on_github" );

    my $ok = $self->do_with_backoff(
        code  => sub {
            eval { $self->repos->delete($self->owner, $repo_on_github); 1 };
        },
        check => method($return) {
            $self->dist_log( "Github repository delete failed" ) if !$return;
            return $return;
        }
    );
    die "Could not delete repository: $@" unless $ok;

    # Sometimes Github doesn't immediately delete the repo, wait
    # until does
    $self->do_with_backoff(
        code  => sub { !$self->exists_on_github }
    );

    return;
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

    my $log_changes = join ", ", map { "$_ => $changes{$_}" } keys %changes;
    $log_changes =~ s{\n}{\\n}g;
    $self->dist_log( "Changing @{[$self->repo]} (as $repo) info: $log_changes" );

    return $self->repos->get($self->owner, $repo)->update(
        \%changes,
    );
}
