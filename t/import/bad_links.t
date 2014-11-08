#!/usr/bin/env perl

# This distribution has dangling symbolic links

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'SMTP-Server';

note "Import $DistName"; {
    my $dist = Gitpan::Dist->new(
        distname => $DistName
    );
    $dist->delete_repo(wait => 1);

    $dist->import_releases(
        before_import   => method($release) {
            note "Importing ".$release->short_path;
        },
        push            => 0,
    );

    cmp_deeply $dist->repo->git->releases, [
        "MACGYVER/SMTP-Server-1.0.tar.gz",
        "MACGYVER/SMTP-Server-1.1.tar.gz",
    ];
}

done_testing;
