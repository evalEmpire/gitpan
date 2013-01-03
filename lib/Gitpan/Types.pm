package Gitpan::Types;

use Mouse::Util::TypeConstraints;

class_type "Path::Class::Dir";
class_type "Path::Class::File";

subtype "Gitpan::AbsDir",
  as "Path::Class::Dir",
  where { $_->is_absolute };

coerce "Gitpan::AbsDir",
  from "Path::Class::Dir",
  via {
      return $_->absolute;
  };

coerce "Gitpan::AbsDir",
  from "Str",
  via {
      require Path::Class;
      return Path::Class::Dir->new($_)->absolute;
  };

coerce "Path::Class::Dir",
  from "Str",
  via {
      require Path::Class;
      return Path::Class::Dir->new($_);
  };

coerce "Path::Class::File",
  from "Str",
  via {
      require Path::Class;
      return Path::Class::File->new($_);
  };

subtype "Gitpan::Distname",
  as "Str",
  message { "A CPAN distribution name" },
  where { !/\s/ and !/::/ };

subtype "Gitpan::Module",
  as "Str",
  message { "A CPAN module name " },
  where { /^[A-Za-z]+ (?: :: \w+)* /x };

1;
