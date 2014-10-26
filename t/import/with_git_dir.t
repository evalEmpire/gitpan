#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'Acme-Warn-LOLCAT';

note "Import $DistName"; {
    my $dist = Gitpan::Dist->new( distname => $DistName );
    $dist->delete_repo( wait => 1 );

    isnt $dist->releases_to_import->size, 0;
    note "Importing ".$dist->paths_to_import->join(", ");

    $dist->import_releases( push => 0 );

    cmp_deeply $dist->repo->releases, [
        "AQUILINA/Acme-Warn-LOLCAT-0.01.tar.gz",
        "AQUILINA/Acme-Warn-LOLCAT-0.02.tar.gz",
    ];
}

done_testing;
