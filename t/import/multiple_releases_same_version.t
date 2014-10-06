#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'Acme-Buffy';

note "Import $DistName"; {
    my $dist = Gitpan::Dist->new( name => 'Acme-Buffy' );
    $dist->delete_repo;

    isnt $dist->releases_to_import->size, 0;
    note "Importing ".$dist->paths_to_import->join(", ");

    $dist->import_releases;

    cmp_deeply $dist->git->releases, [
        "JESSE/Acme-Buffy-1.3.tar.gz",
        "LBROCARD/Acme-Buffy-1.1.tar.gz",
        "LBROCARD/Acme-Buffy-1.2.tar.gz",
        "LBROCARD/Acme-Buffy-1.3.tar.gz",
        "LBROCARD/Acme-Buffy-1.4.tar.gz",
        "LBROCARD/Acme-Buffy-1.5.tar.gz",
        "LBROCARD/Acme-Buffy-1.6.tar.gz",
    ];
}

done_testing;
