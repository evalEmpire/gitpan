package Gitpan::Repo;

use perl5i::2;
use Method::Signatures;

use Gitpan::OO;
use Gitpan::Types;

use Gitpan::Git;
use Gitpan::Github;

use overload
  q[""]     => method { return $self->distname },
  fallback  => 1;

haz distname        => 
  isa       => DistName,
  is        => 'ro',
  required  => 1;

haz cwd     =>
  isa       => AbsPath,
  is        => 'ro',
  required  => 1,
  default   => method {
      return "."->path->absolute;
  },
  documentation => "The current working directory at time of object initialization";

haz directory =>
  isa       => AbsPath,
  is        => 'ro',
  required  => 1,
  lazy      => 1,
  default     => method {
      $self->distname;
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
        $args{distname} = $dist_name;
    }

    return \%args;
}

method _new_github(HashRef $args = {}) {
    return Gitpan::Github->new(
        repo      => $self->distname,
        %$args,
    );
}

method exists_on_github() {
    # Optimization, asking github is expensive
    return 1 if $self->git->remote("origin") =~ /github.com/;
    return $self->github->exists_on_github();
}

method note(@args) {
    # no op for now
}
