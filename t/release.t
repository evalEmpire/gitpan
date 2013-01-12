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

    is $pony->backpan_file->path, "authors/id/D/DC/DCANTRELL/Acme-Pony-1.1.1.tar.gz";
}


done_testing;
        
