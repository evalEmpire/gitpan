package Gitpan::Github;

use Gitpan::perl5i;

use Gitpan::OO;
use Gitpan::Types;
use Pithub;
use Encode;

with 'Gitpan::Role::HasConfig', 'Gitpan::Role::CanBackoff';

method distname { return $self->pithub->repo }
with "Gitpan::Role::CanDistLog";

haz "repo" =>
  is            => 'ro',
  required      => 1;

haz "owner" =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      return $self->config->github_owner;
  };

haz 'token' =>
  is            => 'ro',
  lazy          => 1,
  default       => method {
      return $self->config->github_access_token;
  };

haz pithub =>
  is            => 'ro',
  isa           => InstanceOf['Pithub'],
  lazy          => 1,
  default       => method {
      return Pithub->new(
          user                  => $self->owner,
          repo                  => $self->repo_name_on_github,
          token                 => $self->token,
          per_page              => 100,
          auto_pagination       => 1,
      );
  };

haz "repo_name_on_github" =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      my $repo = $self->repo;

      # Github doesn't like non alphanumerics as repository names.
      # Dots seem ok.
      $repo =~ s{[^a-z0-9-_.]+}{-}ig;

      # Maximum length is 100 characters.
      $repo = substr $repo, 0, 100;

      return $repo;
  };

haz "remote_host" =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      return $self->config->github_remote_host;
  };

haz "remote" =>
  is            => 'ro',
  isa           => Str,
  lazy          => 1,
  default       => method {
      my $owner = $self->owner;
      my $repo  = $self->repo_name_on_github;
      my $token = $self->token;
      my $host  = $self->remote_host;

      return qq[https://$token:\@$host/$owner/$repo.git];
  };

haz "_exists_on_github_cache" =>
  is            => 'rw',
  isa           => Bool,
  default       => 0;

haz "retry_if_not_found" =>
  is            => "rw",
  isa           => Bool,
  default       => 0;

method try_request(
    Int         :$max_tries = 3,
    Bool        :$retry_if_not_found //= $self->retry_if_not_found,
    CodeRef     :$code!,
    CodeRef     :$is_done  = method($result) {
        return $result->success;
    },
    CodeRef     :$is_error = method($result) {
        my $code = $result->response->code;

        # We made a mistake in our request.
        # See https://developer.github.com/v3/#client-errors
        return(1) if $code == 400 || $code == 422;

        # Anything else should be retried.  Might be a hiccup.
        return(0);
    },
    CodeRef     :$final_check = sub { 0 }
) {
    my $result;
    for my $tries (1..$max_tries) {
        $result = $code->();
        return $result if $self->$is_done($result);

        $self->_try_request_error(
            result => $result
        ) if $self->$is_error($result);

        my $http_code = $result->response->code;
        return $result if !$retry_if_not_found && $http_code == 404;

        $self->backoff( tries => $tries, max_tries => $max_tries );

        my $function = (caller(1))[3];
        $self->dist_log( "Retrying $function: HTTP $http_code" );
    }

    return $result if $self->$final_check($result);

    $self->_try_request_error( result => $result );

    return;
}


method _try_request_error(
    Pithub::Result :$result!,
    ArrayRef       :$caller = [caller(2)]
) {
    my $function = $caller->[3];
    my $response = $result->response;
    croak <<"ERROR";
Error in $function, HTTP @{[$response->status_line]}
@{[$result->mo->as_json]}
ERROR

    return;
}


method get_repo_info(
    Bool :$retry_if_not_found //= $self->retry_if_not_found
) {
    my $repo           = $self->repo;
    my $repo_on_github = $self->repo_name_on_github;

    $self->dist_log( "Getting Github repo info for $repo as $repo_on_github" );

    my $result = $self->try_request(
        code                    => sub { return $self->pithub->repos->get },
        retry_if_not_found      => $retry_if_not_found,
        final_check             => method($result) {
            return 1 if $result->response->code == 404;
        }
    );

    return $result->content if $result->success;
    return;
}

method is_empty(
    Bool :$retry_if_not_found //= $self->retry_if_not_found
) {
    my $result = $self->try_request(
        code    => sub {
            return $self->pithub->repos->commits(per_page => 1)->list;
        },
        is_done => method($result) {
            return 1 if $result->success;

            # Github returns this if the repository is empty.
            return 1 if $result->response->code == 409;
        },
        retry_if_not_found => $retry_if_not_found,
    );

    return $result->count ? 0 : 1;
}

method exists_on_github(...) {
    $self->dist_log( "Checking if @{[ $self->repo ]} exists on Github" );

    return 1 if $self->_exists_on_github_cache;

    my $info = $self->get_repo_info(@_);
    $self->_exists_on_github_cache(1) if $info;

    return $info ? 1 : 0;
}

method create_repo(
    :$desc      //= "Read-only release history for @{[$self->repo]}",
    :$homepage  //= "http://metacpan.org/release/@{[$self->repo]}",
    Bool :$retry_if_not_found //= $self->retry_if_not_found
)
{
    my $repo = $self->repo;
    my $repo_name_on_github = $self->repo_name_on_github;

    $self->dist_log( "Creating Github repo for $repo as $repo_name_on_github" );

    my $result = $self->try_request(
        code => sub {
            $self->pithub->repos->create(
                org     => $self->owner,
                data    => {
                    name            => encode_utf8($repo_name_on_github),
                    description     => encode_utf8($desc),
                    homepage        => encode_utf8($homepage),
                    has_issues      => 0,
                    has_wiki        => 0,
                }
            );
        },
        retry_if_not_found => $retry_if_not_found,
    );

    my $created_name  = $result->content->{name};
    croak "Github repo name '$created_name' does not match our expected name '$repo_name_on_github'" if $created_name ne $repo_name_on_github;

    $self->_exists_on_github_cache(1);

    return $result;
}

method maybe_create(
    Str :$desc,
    Str :$homepage,
    Bool :$retry_if_not_found //= $self->retry_if_not_found
)
{
    my $repo = $self->repo;

    return $repo if $self->exists_on_github;
    return $self->create_repo(
        desc        => $desc,
        homepage    => $homepage,
        retry_if_not_found => $retry_if_not_found,
    );
}

method delete_repo_if_exists(
    Bool :$retry_if_not_found //= $self->retry_if_not_found
) {
    return if !$self->exists_on_github(
        retry_if_not_found => $retry_if_not_found,
    );
    return $self->delete_repo(
        retry_if_not_found => $retry_if_not_found,
    );
}

method default_success_check($result) {
    return 1 if $result->success;

    my $code = $result->response->code;
    my $message = $result->content->{message};
    $self->dist_log( "HTTP $code, $message" );

    croak "Unexpected HTTP code $code: $message"
      if $code == 400 or $code == 422;

    return 0;
}

method delete_repo(
    Bool :$retry_if_not_found //= $self->retry_if_not_found
) {
    my $repo           = $self->repo;
    my $repo_on_github = $self->repo_name_on_github;

    $self->dist_log( "Deleting $repo on Github as $repo_on_github" );

    my $result = $self->try_request(
        code  => sub { $self->pithub->repos->delete; },
        retry_if_not_found => $retry_if_not_found,
    );

    $self->_exists_on_github_cache(0);

    return $result;
}

method branch_info(
    Str :$branch //= 'master',
    Bool :$retry_if_not_found //= $self->retry_if_not_found,
) {
    my $result = $self->try_request(
        max_tries       => 6,
        code            => sub {
            $self->dist_log("Trying to get info for $branch");
            return $self->pithub->repos->branch( branch => $branch );
        },
        retry_if_not_found => $retry_if_not_found,
    );

    return $result->content;
}

method change_repo_info(%changes) {
    my $retry_if_not_found =
      delete $changes{retry_if_not_found} // $self->retry_if_not_found;

    return 1 unless keys %changes;

    my $repo = $self->repo_name_on_github;

    # The Github API requires you send the name, even if you're not
    # changing it.  This is silly.
    $changes{name} ||= $repo;

    my $log_changes = join ", ", map { "$_ => $changes{$_}" } keys %changes;
    $log_changes =~ s{\n}{\\n}g;
    $self->dist_log( "Changing @{[$self->repo]} (as $repo) info: $log_changes" );

    my $result = $self->try_request(
        code    => sub {
            $self->dist_log("Trying to change the repository");
            return $self->pithub->repos->update(
                data => \%changes,
            );
        },
        retry_if_not_found => $retry_if_not_found
    );

    return $result;
}
