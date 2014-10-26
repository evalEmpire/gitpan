#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Dist';

require_ok $CLASS;

note "Required args"; {
    throws_ok { $CLASS->new } qr/^distname or backpan_dist required/;
}

note "The basics"; {
    my $dist = $CLASS->new( distname => "Acme-Pony" );

    is $dist->backpan_dist->name, $dist->distname;

    my $releases = $dist->backpan_releases;
    cmp_ok $releases->count, ">=", 2;
    my $first_release = $releases->first;
    isa_ok $first_release, "BackPAN::Index::Release";
    is $first_release->version, '1.1.1';
}


note "new() from BackPAN::Index::Dist"; {
    my $bp_dist = $CLASS->new( distname => "Acme-Pony" )->backpan_dist;

    my $dist = $CLASS->new( backpan_dist => $bp_dist );
    is $dist->distname, 'Acme-Pony';
}


note "release_from_version"; {
    my $dist = $CLASS->new( distname => "Acme-Pony" );

    my $release = $dist->release_from_version('1.1.1');
    isa_ok $release, "Gitpan::Release";
    is $release->distname, "Acme-Pony";
    is $release->version,  "1.1.1";
}


note "release_from_backpan"; {
    my $dist = $CLASS->new( distname => "Acme-Buffy" );

    # There are two releases for 1.3
    my @bp_releases = $dist->backpan_releases->search({ version => '1.3' })->all;
    for my $bp_release (@bp_releases) {
        my $release = Gitpan::Release->new(
            backpan_release => $bp_release
        );
        is $release->version,  '1.3';
        is $release->distname, 'Acme-Buffy';
    }
}

note "dist data"; {
    my $dist = $CLASS->new( distname => "Foo-Bar" );
    isa_ok $dist, $CLASS;

    is $dist->distname, "Foo-Bar";
}


note "releases to import"; {
    my $dist = new_dist( distname => 'Acme-LookOfDisapproval' );

    # Releaes of Acme-LOD as of this writing.
    my @backpan_versions = (0.001, 0.002, 0.003, 0.004, 0.005, 0.006);
    my @backpan_paths    = (
        "ETHER/Acme-LookOfDisapproval-0.001.tar.gz",
        "ETHER/Acme-LookOfDisapproval-0.002.tar.gz",
        "ETHER/Acme-LookOfDisapproval-0.003.tar.gz",
        "ETHER/Acme-LookOfDisapproval-0.004.tar.gz",
        "ETHER/Acme-LookOfDisapproval-0.005.tar.gz",
        "ETHER/Acme-LookOfDisapproval-0.006.tar.gz",
    );
    cmp_deeply scalar @backpan_versions->diff($dist->versions_to_import), [];
    cmp_deeply scalar @backpan_paths   ->diff($dist->paths_to_import),    [];

    my $git = $dist->git;
    $git->repo_dir->child("foo")->touch;
    $git->add_all;
    $git->commit( message => "Adding foo" );
    $git->tag_release( $dist->release_from_version(0.001) );

    cmp_deeply scalar @backpan_versions->diff($dist->versions_to_import), [0.001];
    cmp_deeply scalar @backpan_paths->diff($dist->paths_to_import),
      ['ETHER/Acme-LookOfDisapproval-0.001.tar.gz'];
}

note "restarting from an existing repository"; {
    note "Import a release to establish the repository"; {
        my $dist = Gitpan::Dist->new(
            distname    => 'Acme-LookOfDisapproval'
        );
        $dist->delete_repo( wait => 1 );
        $dist->repo->import_release( $dist->release_from_version(0.001), push => 1 );
    }

    my $dist = Gitpan::Dist->new(
        distname    => 'Acme-LookOfDisapproval'
    );
    cmp_deeply $dist->repo->releases, ["ETHER/Acme-LookOfDisapproval-0.001.tar.gz"];
}

done_testing;
