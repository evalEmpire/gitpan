#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;
use Gitpan::Release;

note "Required args"; {
    dies_ok { Gitpan::Release->new; };
    dies_ok {
        Gitpan::Release->new( distname => "Acme-Pony" );
    };
    dies_ok {
        Gitpan::Release->new( version => '1.1.1' );
    };
}


note "The basics"; {
    my $pony = Gitpan::Release->new(
        distname => 'Acme-Pony',
        version  => '1.1.1'
    );
    isa_ok $pony, "Gitpan::Release";

    is $pony->path,       "authors/id/D/DC/DCANTRELL/Acme-Pony-1.1.1.tar.gz";
    is $pony->short_path, "DCANTRELL/Acme-Pony-1.1.1.tar.gz";
}


note "Author info"; {
    my $pony = Gitpan::Release->new(
        distname => 'Acme-Pony',
        version  => '1.1.1'
    );
    isa_ok $pony, "Gitpan::Release";

    my $author = $pony->author;
    isa_ok $author, "CPANPLUS::Module::Author";
    is $author->cpanid, "DCANTRELL";
    like $author->author, qr{Cantrell}i;
}


note "get"; {
    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1'
    ];

    my $file = $pony->archive_file;
    like $file, qr{Acme-Pony};
    ok !-e $file;

    my $res = $pony->get;
    ok $res->is_success;
    ok -e $file;
}


note "extract"; {
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
}

done_testing;
