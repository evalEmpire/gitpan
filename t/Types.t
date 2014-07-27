#!/usr/bin/perl

use perl5i::2;
use Test::More;
use Test::TypeConstraints;
use Gitpan::Types;

note "Path types"; {
    type_isa "/foo/bar/baz.txt", "Path::Tiny", "str to file coercion",   coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/foo/bar/baz.txt";
    };

    type_isa "/what/stuff",      "Path::Tiny",  "str to dir coercion",    coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/what/stuff";
    };

    type_isa "/up/down/left",    "Gitpan::AbsDir",    "str to absdir coercion", coerce => sub {
        isa_ok $_[0], "Path::Tiny";
        is $_[0], "/up/down/left";
    };

    type_isnt "this/that",       "Gitpan::AbsDir";
}

note "Dist and module types"; {
    type_isa  "Foo-Bar",          "Gitpan::Distname";
    type_isa  "Foo",              "Gitpan::Distname";
    type_isnt "Foo::Bar",         "Gitpan::Distname";

    type_isa  "Foo::Bar",         "Gitpan::Module";
    type_isa  "Foo",              "Gitpan::Module";
    type_isnt "123::Foo",         "Gitpan::Module";
}

note "URI coercion"; {
    type_isa "http://example.com", "URI", "str to URI coercion",   coerce => sub {
        isa_ok $_[0], "URI";
        is $_[0], "http://example.com";
    };
}


done_testing;
