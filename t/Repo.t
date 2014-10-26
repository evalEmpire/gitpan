#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "basics" => sub {
    my $repo = new_repo;

    ok !$repo->has_github,      "github is created lazily";
    ok !$repo->has_git,         "git is created lazily";
};


note "github"; {
    my $repo = new_repo;

    my $gh = $repo->github;
    isa_ok $gh, "Gitpan::Github";
    is $gh->owner, "gitpan-test";
    is $gh->repo,  $repo->distname;
}


note "git"; {
    my $repo = new_repo;

    my $git = $repo->git;
    isa_ok $git, "Gitpan::Git";

    ok -d $repo->repo_dir;
    ok -d $repo->repo_dir->child(".git");

    my $name_path = $repo->distname_path;
    like $repo->repo_dir, qr{\Q$name_path}, "repo_dir contains the dist name";
}


note "delete_repo that doesn't exist"; {
    my $repo = new_repo;

    ok !$repo->github->exists_on_github;
    ok !-e $repo->repo_dir;

    $repo->delete_repo;

    ok !-e $repo->repo_dir;
    ok !$repo->github->exists_on_github;
}


note "delete_repo"; {
    my $repo = new_repo;

    $repo->github->maybe_create;
    my $git = $repo->git;

    ok -e $repo->repo_dir;
    ok $repo->github->exists_on_github;

    $repo->delete_repo;

    ok !-e $repo->repo_dir;
    ok !$repo->github->exists_on_github;
    ok !$repo->has_git;
}


subtest "empty repo" => sub {
    my $repo = new_repo;
    ok !$repo->have_git_repo;
    ok !$repo->have_github_repo;

    cmp_deeply $repo->releases, [];
    ok !$repo->have_git_repo, "releases() does not create a git repo";
};

done_testing;
