package Gitpan::Config;

use Gitpan::OO;
use Gitpan::Types;
use Gitpan::perl5i;

haz backpan_url =>
  is            => 'ro',
  isa           => URI,
  default       => 'http://gitpan.integra.net/backpan';

haz backpan_cache_ttl =>
  is            => 'ro',
  isa           => Int,
  default       => 60 * 60;

haz backpan_always_update =>
  is            => 'ro',
  isa           => Bool,
  default       => 0;

haz backpan_normalize_dist_names =>
  is            => 'ro',
  isa           => HashRef,
  default       => method { {} };

haz backpan_normalize_releases =>
  is            => 'ro',
  isa           => HashRef[HashRef[Str]],
  default       => method { {} };

haz committer_email =>
  is            => 'ro',
  isa           => Str,
  default       => 'schwern+gitpan@pobox.com';

haz committer_name =>
  is            => 'ro',
  isa           => Str,
  default       => 'Gitpan';

haz "github_owner" =>
  is            => 'ro',
  isa           => Str,
  default       => 'gitpan';

haz "github_access_token" =>
  is            => 'ro',
  isa           => Str,
  default       => sub {
      return $ENV{GITPAN_GITHUB_ACCESS_TOKEN} ||
             # A read only token for testing
             "f58a7dfa0f749ccb521c8da38f9649e2eff2434f"
  };

haz "github_remote_host" =>
  is            => 'ro',
  isa           => Str,
  default       => 'github.com';

haz "gitpan_dir" =>
  is            => 'ro',
  isa           => Path,
  default       => sub {
      return "$ENV{HOME}/gitpan"->path;
  };

haz "gitpan_log_dir" =>
  is            => 'ro',
  isa           => Path,
  lazy          => 1,
  default       => method {
      return $self->gitpan_dir->child("log");
  };

haz "gitpan_log_file" =>
  is            => 'ro',
  isa           => Path,
  lazy          => 1,
  default       => method {
      return $self->gitpan_log_dir->child("gitpan.log");
  };

haz "gitpan_repo_dir" =>
  is            => 'ro',
  isa           => Path,
  lazy          => 1,
  default       => method {
      return $self->gitpan_dir->child("repo");
  };

haz cpan_release_tag_prefix =>
  is            => 'ro',
  isa           => Str,
  default       => "cpan_version/";

haz gitpan_release_tag_prefix =>
  is            => 'ro',
  isa           => Str,
  default       => "gitpan_version/";

haz cpan_path_tag_prefix =>
  is            => 'ro',
  isa           => Str,
  default       => "cpan_path/";


{
    my $default;
    method default($class:) {
        require Gitpan::ConfigFile;
        return $default //= Gitpan::ConfigFile->default->config;
    }

    method set_default($class: Gitpan::Config $new_default) {
        $default = $new_default;
        return;
    }
}


method BUILD(...) {
    $self->gitpan_dir->mkpath;
    $self->gitpan_log_dir->mkpath;
    $self->gitpan_repo_dir->mkpath;

    return;
}


=head1 NAME

Gitpan::Config - Configuration of Gitpan

=head1 DESCRIPTION

Contains the configuration for Gitpan as read from a
L<Gitpan::ConfigFile>.

Gitpan classes should not hard code values or defaults, instead they
should be used here.

Gitpan classes should gain access to Gitpan::Config via
L<Gitpan::Role::HasConfig>.

=head2 Methods

=head3 github_owner

The Github account (owner) whose repositories we're accessing.

Defaults to 'gitpan'.

=head3 github_access_token

The Github API access token used to access the github_owner's account.

Defaults to the GITPAN_GITHUB_ACCESS_TOKEN environment variable or a
read-only token for testing purposes.

=head3 github_remote_host

The remote host for Github.

Defaults to github.com.

=head1 ENVIRONMENT

=head3 GITPAN_GITHUB_ACCESS_TOKEN

See L</github_access_token>.

=head1 NOTES

Configuration is very simple and flat right now.  This may change once
the configuration becomes more complicated.

=cut
