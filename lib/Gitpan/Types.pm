package Gitpan::Types;

use MooseX::Types -declare => [qw(Dir Distname AbsDir)];
use MooseX::Types::Moose qw(Object Str);

subtype Dir,
  as "Path::Class::Dir";

coerce Dir,
  from Str,
  via  {
      require Path::Class;
      return Path::Class::Dir->new($_);
  };


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
  where { !/\s/ };

1;
