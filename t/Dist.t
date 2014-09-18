#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Dist';

require_ok $CLASS;

# Simulate a non-configured system as when testing on Travis.
local $ENV{GIT_COMMITTER_NAME} = '';

note "Required args"; {
    throws_ok { $CLASS->new } qr/^Missing required arguments: name/;
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

note "Recover from a module name"; {
    my $dist = $CLASS->new( modulename => "This::That::Whatever" );
    is $dist->name, "This-That-Whatever";
}

note "release"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

    my $release = $dist->release( version => '1.1.1' );
    isa_ok $release, "Gitpan::Release";
    is $release->distname, "Acme-Pony";
    is $release->version,  "1.1.1";
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
    diag("add_all");
    $git->add_all;
    diag("commit");
    $git->run( "commit" => "-m", "Adding foo" );
    diag("tag_release");
    $git->tag_release( $dist->release(version => 0.001) );

    cmp_deeply scalar @backpan_versions->diff($dist->versions_to_import), [0.001];
}

done_testing;
