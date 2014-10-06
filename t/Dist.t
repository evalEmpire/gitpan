#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Dist';

require_ok $CLASS;

note "Required args"; {
    throws_ok { $CLASS->new } qr/^name or backpan_dist required/;
}

note "The basics"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

    ok !$dist->has_git;
    ok !$dist->has_github;

    is $dist->backpan_dist->name, $dist->name;

    my $releases = $dist->backpan_releases;
    cmp_ok $releases->count, ">=", 2;
    my $first_release = $releases->first;
    isa_ok $first_release, "BackPAN::Index::Release";
    is $first_release->version, '1.1.1';
}


note "new() from BackPAN::Index::Dist"; {
    my $bp_dist = $CLASS->new( name => "Acme-Pony" )->backpan_dist;

    my $dist = $CLASS->new( backpan_dist => $bp_dist );
    is $dist->name, 'Acme-Pony';
}


note "release_from_version"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

    my $release = $dist->release_from_version('1.1.1');
    isa_ok $release, "Gitpan::Release";
    is $release->distname, "Acme-Pony";
    is $release->version,  "1.1.1";
}


note "release_from_backpan"; {
    my $dist = $CLASS->new( name => "Acme-Buffy" );

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
    my $dist = $CLASS->new( name => "Foo-Bar" );
    isa_ok $dist, $CLASS;

    is $dist->name, "Foo-Bar";
}


note "github"; {
    my $dist = $CLASS->new( name => "Foo-Bar" );
    my $gh = $dist->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->owner, "gitpan-test";
    is $gh->repo,  "Foo-Bar";

    $dist->github({ login => "wibble", access_token => 12345 });
    $gh = $dist->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->login, "wibble";
    is $gh->access_token, 12345;
    is $gh->owner, "gitpan-test";
    is $gh->repo,  "Foo-Bar";

    my $dist2 = $CLASS->new(
        name      => "Test-This",
    );
    $dist2->github({
        access_token => 54321,
        login        => 12345,
    });
    isa_ok $dist2, $CLASS;
    $gh = $dist2->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->login, "12345";
    is $gh->access_token, "54321";
    is $gh->owner, "gitpan-test";
    is $gh->repo,  "Test-This";
}


note "git"; {
    my $dist = $CLASS->new( name => "Foo-Bar" );
    my $git = $dist->git;
    isa_ok $git, "Gitpan::Git";
    ok -d $dist->repo_dir;
    ok -d $dist->repo_dir->child(".git");

    my $name_path = $dist->distname_path;
    like $dist->repo_dir, qr{\Q$name_path}, "repo_dir contains the dist name";

    $dist->delete_repo;
}


note "releases to import"; {
    my $dist = Gitpan::Dist->new(
        name    => 'Acme-LookOfDisapproval'
    );
    $dist->delete_repo;

    # Releaes of Acme-LOD as of this writing.
    my @backpan_versions = (0.001, 0.002, 0.003, 0.004, 0.005, 0.006);
    cmp_deeply scalar @backpan_versions->diff($dist->versions_to_import), [];

    my $git = $dist->git;
    $git->repo_dir->child("foo")->touch;
    $git->add_all;
    $git->run( "commit" => "-m", "Adding foo" );
    $git->tag_release( $dist->release_from_version(0.001) );

    cmp_deeply scalar @backpan_versions->diff($dist->versions_to_import), [0.001];
}

note "restarting from an existing repository"; {
    note "Import a release to establish the repository"; {
        my $dist = Gitpan::Dist->new(
            name    => 'Acme-LookOfDisapproval'
        );
        $dist->delete_repo;
        $dist->import_release( $dist->release_from_version(0.001) );
    }

    my $dist = Gitpan::Dist->new(
        name    => 'Acme-LookOfDisapproval'
    );
    cmp_deeply $dist->git->releases, [0.001];
}

done_testing;
