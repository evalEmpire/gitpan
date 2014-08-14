#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

subtest "version normalization" => sub {
    my $dist = Gitpan::Dist->new(
        name    => 'Acme-eng2kor'
    );
    $dist->delete_repo;

    $dist->import_releases(
        before_import   => method($release) {
            note "Importing ".$release->version;
        }
    );

    my $git = $dist->git;

    cmp_deeply [$git->cpan_versions],   [ "0.0.1", "v0.0.2" ];
    cmp_deeply [$git->gitpan_versions], [ "0.0.1", "0.0.2" ];
    cmp_deeply [$git->cpan_paths], [
        "AANOAA/Acme-eng2kor-0.0.1.tar.gz",
        "AANOAA/Acme-eng2kor-v0.0.2.tar.gz"
    ];
};

done_testing;
