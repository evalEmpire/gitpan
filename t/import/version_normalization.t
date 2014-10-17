#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

subtest "version normalization" => sub {
    my $dist = Gitpan::Dist->new(
        name    => 'Acme-eng2kor'
    );
    diag "Deleting the repo";
    $dist->delete_repo;

    $dist->import_releases(
        before_import   => method($release) {
            diag "Importing ".$release->version;
        },
        push            => 0,
        after_import    => method($release) {
            diag "Imported ".$release->version;
        },
    );

    my $git = $dist->git;

    diag "Checking versions";
    cmp_deeply [$git->cpan_versions],   [ "0.0.1", "v0.0.2" ];
    cmp_deeply [$git->gitpan_versions], [ "0.0.1", "0.0.2" ];
    cmp_deeply [$git->cpan_paths], [
        "AANOAA/Acme-eng2kor-0.0.1.tar.gz",
        "AANOAA/Acme-eng2kor-v0.0.2.tar.gz"
    ];

    diag "Subtest done";
};

done_testing;
