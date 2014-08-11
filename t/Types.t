#!/usr/bin/perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;
use Test::TypeConstraints;
use Gitpan::Types;

note "Path types"; {
    type_isa "/foo/bar/baz.txt", Path, "str to file coercion",   coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/foo/bar/baz.txt";
    };

    type_isa "/what/stuff",      Path,  "str to dir coercion",    coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/what/stuff";
    };

    type_isa "/up/down/left",    AbsPath,    "str to absdir coercion", coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/up/down/left";
    };

    type_isnt "this/that",       AbsPath;
}

note "Dist and module types"; {
    type_isa  "Foo-Bar",          DistName;
    type_isa  "Foo",              DistName;
    type_isnt "Foo::Bar",         DistName;

    type_isa  "Foo::Bar",         ModuleName;
    type_isa  "Foo",              ModuleName;
    type_isnt "123::Foo",         ModuleName;
}

note "URI coercion"; {
    type_isa "http://example.com", URI, "str to URI coercion",   coerce => sub {
        isa_ok $_[0], "URI";
        is $_[0], "http://example.com";
    };
}

note "Extra URI methods"; {
    require URI;
    is "URI"->new("http://example.com/foo/")->append_path("/blah/blat"),
      "http://example.com/foo/blah/blat";

    is "URI"->new("http://example.com/foo")->append_path("blah/blat"),
      "http://example.com/foo/blah/blat";
}

done_testing;
