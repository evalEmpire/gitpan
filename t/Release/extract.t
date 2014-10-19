#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;

use Gitpan::Test;
use Gitpan::Release;


subtest "basic extract" => sub {
    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1'
    ];

    throws_ok {
        $pony->extract;
    } qr{\Q@{[$pony->archive_file]} does not exist};

    $pony->get;
    my $path = $pony->extract;
    is $path, $pony->extract_dir;
    ok -d $path;
    ok -e $path->child("Makefile.PL");
};


subtest "empty archive" => sub {
    my $empty = new_ok "Gitpan::Release", [
        distname        => 'Bundle-Slash',
        version         => '2.11'
    ];

    $empty->get;

    throws_ok {
        $empty->extract;
    } qr{^Archive is empty};

    ok !$empty->extract_dir;
};


done_testing;
