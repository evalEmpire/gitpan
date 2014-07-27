package Gitpan::Types;

use perl5i::2;
use Mouse::Util::TypeConstraints;

class_type "BackPAN::Index";
class_type "File::Temp::Dir";
class_type "File::Temp";
class_type "Gitpan::Dist";
class_type "Gitpan::Repo";
class_type "Path::Tiny";
class_type "URI";

subtype "Gitpan::AbsDir",
  as "Path::Tiny",
  where { $_->is_absolute };

coerce "Gitpan::AbsDir",
  from "Path::Tiny",
  via {
      return $_->absolute;
  };

coerce "Gitpan::AbsDir",
  from "Str",
  via {
      return $_->path->absolute;
  };

coerce "Path::Tiny",
  from "Str",
  via {
      return $_->path;
  };

subtype "Gitpan::Distname",
  as "Str",
  message { "A CPAN distribution name" },
  where { !/\s/ and !/::/ };

subtype "Gitpan::Module",
  as "Str",
  message { "A CPAN module name " },
  where { /^[A-Za-z]+ (?: :: \w+)* /x };

coerce "URI",
  from "Str",
  via {
      require URI;
      return URI->new($_);
  };

1;
