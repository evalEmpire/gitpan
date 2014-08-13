#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

subtest "Setup class" => sub {
    package Foo;
    use Gitpan::OO;
    use Gitpan::Types;

    haz distname =>
      isa       => Str,
      required  => 1;

    with
      "Gitpan::Role::CanDistLog",
      "Gitpan::Role::HasConfig";

    ::pass;
};


subtest "distname_path" => sub {
    my $obj = Foo->new( distname => "F-B-D" );
    is $obj->distname_path, "F-/F-B-D";

    $obj = Foo->new( distname => "F" );
    is $obj->distname_path, "F/F";

    $obj = Foo->new( distname => "acme-pony" );
    is $obj->distname_path, "AC/acme-pony";
};


subtest "dist_log" => sub {
    my $obj = Foo->new( distname => "Foo-Bar" );
    $obj->dist_log("something");
    $obj->dist_log("and something\n");
    $obj->dist_log("with ünicode");

    like $obj->dist_log_file, qr{FO/Foo-Bar};

    is $obj->dist_log_file->slurp_utf8, <<'END';
something
and something
with ünicode
END
};


done_testing;

