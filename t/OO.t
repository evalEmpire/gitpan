#!/usr/bin/env perl

use perl5i::2;
use Test::Most;

note "haz"; {
    {
        package Foo;
        use Gitpan::OO;
        use Gitpan::MooTypes;

        has "stuff" =>
          is        => 'rw';

        haz "thing";

        haz "file"  =>
          isa       => Path;
    }

    my $obj = new_ok "Foo";

    $obj->stuff(23);
    is $obj->stuff, 23, "has works";

    $obj->thing(42);
    is $obj->thing, 42, "haz defaults to rw";

    $obj->file("/foo/bar/baz");
    is $obj->file, "/foo/bar/baz";
    isa_ok $obj->file, "Path::Tiny", "coercion is automatic";
}

done_testing;
