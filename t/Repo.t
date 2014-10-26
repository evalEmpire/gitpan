#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "basics" => sub {
    my $repo = $CLASS->new( distname => 'Acme-Pony' );

    ok !$repo->has_github,      "github is created lazily";
    ok !$repo->has_git,         "git is created lazily";
};


note "github"; {
    my $repo = $CLASS->new( distname => "Foo-Bar" );

    my $gh = $repo->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->owner, "gitpan-test";
    is $gh->repo,  "Foo-Bar";
}


note "git"; {
    my $repo = $CLASS->new( distname => "Foo-Bar" );

    my $git = $repo->git;
    isa_ok $git, "Gitpan::Git";

    ok -d $repo->repo_dir;
    ok -d $repo->repo_dir->child(".git");

    my $name_path = $repo->distname_path;
    like $repo->repo_dir, qr{\Q$name_path}, "repo_dir contains the dist name";
}


note "delete_repo that doesn't exist"; {
    my $repo = $CLASS->new( distname => "Blah-Blah-Blah" );

    ok !$repo->github->exists_on_github;
    ok !-e $repo->repo_dir;

    $repo->delete_repo;

    ok !-e $repo->repo_dir;
    ok !$repo->github->exists_on_github;
}


note "delete_repo"; {
    my $repo = $CLASS->new( distname => "Some-Repo-Thing" );

    $repo->github->maybe_create;
    my $git = $repo->git;

    ok -e $repo->repo_dir;
    ok $repo->github->exists_on_github;

    $repo->delete_repo;

    ok !-e $repo->repo_dir;
    ok !$repo->github->exists_on_github;
    ok !$repo->has_git;
}


done_testing;
