#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

subtest "dist name normalization" => sub {
    my $dist = Gitpan::Dist->new( name => "URIC" );
    my $v200 = $dist->release_from_version("2.00");
    my $v202 = $dist->release_from_version("2.02");

    is $v200->short_path, 'LDACHARY/uri-2.00.tar.gz';
    is $v202->short_path, 'LDACHARY/URIC-2.02.tar.gz';
};

subtest "release normalization" => sub {
    my $dist = Gitpan::Dist->new( name => "Bi");

    my $release = $dist->release_from_version("0.01");
    is $release->short_path, "MARCEL/-0.01.tar.gz";
};

done_testing;
