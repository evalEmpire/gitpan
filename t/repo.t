#!/usr/bin/perl

use strict;
use warnings;

use Path::Class;
use Test::More;

use Gitpan::Repo;

my $repo = Gitpan::Repo->new( distname => "Foo-Bar" );
isa_ok $repo, "Gitpan::Repo";


# repo data
{
    is $repo->distname, "Foo-Bar";
    is $repo->directory, dir("Foo-Bar")->absolute;
}


# github
{
    my $gh = $repo->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->owner, "gitpan";
    is $gh->login, "gitpan";
    is $gh->repo,  "Foo-Bar";

    $gh = $repo->github({ login => "wibble", token => 12345 });
    isa_ok $gh, "Gitpan::Github";
    is $gh->login, "wibble";
    is $gh->token, 12345;
    is $gh->owner, "gitpan";
    is $gh->repo,  "Foo-Bar";

    my $repo2 = Gitpan::Repo->new(
        distname  => "Test-This",
        directory => "foo/bar",
        github    => {
            token => 54321,
            login => 12345,
        }
    );
    isa_ok $repo2, "Gitpan::Repo";
    $gh = $repo2->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->login, "12345";
    is $gh->token, "54321";
    is $gh->owner, "gitpan";
    is $gh->repo,  "Test-This";
}


# git
{
    my $git = $repo->git;
    isa_ok $git, "Gitpan::Git";
    ok -d $repo->directory;
    END { $repo->directory->rmtree }

    ok -d $repo->directory->subdir(".git");
}

done_testing;
