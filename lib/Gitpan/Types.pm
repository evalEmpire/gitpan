package Gitpan::Types;

use Gitpan::perl5i;

use Type::Library -base;
use Type::Utils -all;
BEGIN { extends "Types::Standard" }

sub import {
    # Export :types by default.
    push @_, ":types" if @_ == 1;
    goto __PACKAGE__->can("SUPER::import");
}

class_type "BackPAN::Index";
class_type "Gitpan::Dist";
class_type "Gitpan::Repo";


declare "Path",
  as InstanceOf["Path::Tiny"];

coerce "Path",
  from Str,
  via {
      return $_->path;
  };


declare "AbsPath",
  as "Path",
  where { $_->is_absolute };

coerce "AbsPath",
  from "Path",
  via {
      return $_->absolute;
  };

coerce "AbsPath",
  from Str,
  via {
      return $_->path->absolute;
  };


declare "DistName",
  as Str,
  message { "A CPAN distribution name" },
  where { length and !/\s/ and !/::/ };


declare "ModuleName",
  as Str,
  message { "A CPAN module name " },
  where { /^[A-Za-z]+ (?: :: \w+)* /x };


declare "URI",
  as InstanceOf["URI"];

coerce "URI",
  from Str,
  via {
      require URI;
      return URI->new($_);
  };

# Fuck Typing
sub URI::append_path {
    my $self = shift;
    my $to_append = shift;

    my $path = $self->path;
    $path =~ s{/$}{};
    $to_append =~ s{^/}{};

    $self->path($path ."/". $to_append);

    return $self;
}
