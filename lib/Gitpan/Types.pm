package Gitpan::Types;

use MooseX::Types -declare => [qw(Dir Distname AbsDir)];
use MooseX::Types::Moose qw(Object Str);

subtype Dir,
  as Object,
  message { "A directory path" };

coerce Dir,
  from Str,
  via  {
      require Path::Class;
      return Path::Class->dir($_);
  };


subtype AbsDir,
  as Dir,
  message { "An absolute directory " };

coerce AbsDir,
  from Dir,
  via {
      return $_->absolute;
  };


subtype Distname,
  as Str,
  message { "A CPAN distribution name" },
  where { !/\s/ };

1;
