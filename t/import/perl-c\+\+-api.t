#!/usr/bin/env perl

# This distribution has proven a problem in the past.

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'perl-c++-api';

note "Import $DistName"; {
    my $dist = Gitpan::Dist->new(
        name        => $DistName
    );
    $dist->delete_repo;

    cmp_deeply $dist->versions_to_import, ['0.0_2', '0.0_3'];

    $dist->import_releases;

    my($last_commit) = $dist->git->log("-1");
    like $last_commit->message, qr{^gitpan-cpan-maturity:\s+developer}ms;
}

done_testing;
