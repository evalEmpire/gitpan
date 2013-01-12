#!/usr/bin/env perl

use strict;
use warnings;

use perl5i::2;

use Test::Most;

my $CLASS = 'Gitpan::Dist';

require_ok $CLASS;

note "Required args"; {
    throws_ok { $CLASS->new } qr/Attribute.*name.*required/;
}

note "The basics"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

    my $repo = $dist->repo;
    is $repo->distname, $dist->name;

    is $dist->backpan_dist->name, $dist->name;

    my $releases = $dist->backpan_releases;
    cmp_ok $releases->count, ">=", 2;
    my $first_release = $releases->first;
    isa_ok $first_release, "BackPAN::Index::Release";
    is $first_release->version, '1.1.1';
}

note "release"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

    my $release = $dist->release( version => '1.1.1' );
    isa_ok $release, "Gitpan::Release";
    is $release->distname, "Acme-Pony";
    is $release->version,  "1.1.1";
}

done_testing;
