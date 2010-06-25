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
}


# git
{
    my $git = $repo->git;
    isa_ok $git, "Git";
    ok -d $repo->directory;
    END { $repo->directory->rmtree }

    ok -d $repo->directory->subdir(".git");
}

done_testing;
