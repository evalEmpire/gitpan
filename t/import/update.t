#!/usr/bin/env perl

# This distribution has proven a problem in the past.

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'Acme-LookOfDisapproval';

subtest "Import $DistName and update" => sub {
    my $dist = Gitpan::Dist->new(
        distname => $DistName
    );
    $dist->delete_repo( wait => 1 );

    my $to_import = $dist->releases_to_import;
    cmp_ok @$to_import, '>=', 4;

    my $repo = $dist->repo;
    note "Importing and pushing first batch";
    my $first_releases = [shift @$to_import, shift @$to_import];
    ok $repo->import_releases(
        releases => $first_releases
    );

    note "Importing and pushing second batch";
    my $second_releases = [shift @$to_import, shift @$to_import];
    ok $repo->import_releases(
        releases => $second_releases
    );

    $dist->delete_repo;
};

done_testing;
