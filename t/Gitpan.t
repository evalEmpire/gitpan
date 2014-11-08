#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::Test;
use Gitpan::perl5i;

my $CLASS = 'Gitpan';

require_ok $CLASS;

subtest "timestamps" => sub {
    my $gitpan = new_ok $CLASS;

    my $date = $gitpan->latest_release_date;
    # This will break in about three years, sorry future.
    like $date, qr{\A 14\d{8} \z}x;

    is $gitpan->read_latest_release_timestamp, 0;

    $gitpan->write_latest_release_timestamp( $date );
    is $gitpan->read_latest_release_timestamp, $date;
};


done_testing;
