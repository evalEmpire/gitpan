package Gitpan::Dist;

use perl5i::2;
use Method::Signatures;

use Gitpan::OO;
use Gitpan::Types;

with 'Gitpan::Role::HasBackpanIndex';

use Path::Tiny;
use Gitpan::Git;
use Gitpan::Github;

use overload
  q[""]     => method { return $self->name },
  fallback  => 1;

haz name =>
  is            => 'ro',
  isa           => DistName,
  required      => 1;

haz directory =>
  isa       => AbsPath,
  is        => 'ro',
  required  => 1,
  lazy      => 1,
  default     => method {
      return $ENV{GITPAN_TEST} ? Path::Tiny->tempdir : $self->name;
  };

haz git     =>
  isa       => InstanceOf["Gitpan::Git"],
  required  => 1,
  lazy      => 1,
  default   => method {
      local $SIG{__DIE__};  # Moo bug
      my $github = $self->github;
      $github->maybe_create;

      return Gitpan::Git->clone(repo_dir => $self->directory, url => $github->remote);
  };

haz github  =>
  isa       => HashRef|InstanceOf['Gitpan::Github'],
  lazy      => 1,
  coerce    => 0,
  trigger   => method($new, $old?) {
      return $new if $new->isa("Gitpan::Github");
      my $gh = $self->_new_github($new);
      $self->github( $gh );
  },
  default   => method {
      return $self->_new_github;
  };

method BUILDARGS($class: %args) {
    if( my $module_name = delete $args{modulename} ) {
        my $dist_name = $module_name;
        $dist_name =~ s{::}{-}g;
        $args{name} = $dist_name;
    }

    return \%args;
}

method _new_github(HashRef $args = {}) {
    return Gitpan::Github->new(
        repo      => $self->name,
        %$args,
    );
}

method exists_on_github() {
    # Optimization, asking github is expensive
    return 1 if $self->git->remote("origin") =~ /github.com/;
    return $self->github->exists_on_github();
}

method backpan_dist {
    return $self->backpan_index->dist($self->name);
}

method backpan_releases {
    return $self->backpan_dist->releases->search(
        # Ignore ppm releases, we only care about source releases.
        { path => { 'not like', '%.ppm' } },
        { order_by => { -asc => "date" } } );
}

method release(Str :$version) {
    require Gitpan::Release;
    return Gitpan::Release->new(
        distname        => $self->name,
        version         => $version
    );
}

method releases_to_import() {
    my $backpan_releases = $self->backpan_releases;
    my @backpan_versions = map { $_->version } $backpan_releases->all;

    my $gitpan_releases = $self->repo->git->releases;

    return @backpan_versions->diff($gitpan_releases);
}
