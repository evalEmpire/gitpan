#!/usr/bin/env perl

use lib 't/lib';
use perl5i::2;
use Gitpan::Test;

my $CLASS = 'Gitpan::Dist';

require_ok $CLASS;

note "Required args"; {
    throws_ok { $CLASS->new } qr/^Missing required arguments: name/;
}

note "The basics"; {
    my $dist = $CLASS->new( name => "Acme-Pony" );

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
    ok $dist->directory->is_absolute;
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
        directory => "foo/bar"
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
    ok -d $dist->directory;
    ok -d $dist->directory->child(".git");
}

done_testing;
