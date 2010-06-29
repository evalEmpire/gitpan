package Gitpan::Types;

use MooseX::Types -declare => [qw(Distname AbsDir Module)];
use MooseX::Types::Path::Class qw(Dir File);
use MooseX::Types::Moose qw(Object Str HashRef);

subtype AbsDir,
  as Dir,
  where { $_->is_absolute };

coerce AbsDir,
  from Dir,
  via {
      return $_->absolute;
  };

coerce AbsDir,
  from Str,
  via {
      require Path::Class;
      return Path::Class::Dir->new($_)->absolute;
  };

subtype Distname,
  as Str,
  message { "A CPAN distribution name" },
  where { !/\s/ and !/::/ };

coerce Distname,
  from Str,
  via {
      s/::/-/g;
      return $_;
  };

subtype Module,
  as Str,
  message { "A CPAN module name " },
  where { /^[A-Za-z]+ (?: :: \w+)+ /x };

1;
