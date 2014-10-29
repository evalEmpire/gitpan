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


subtest "releases() syncs from Github" => sub {
    my $dist = new_dist( distname => "Acme-Pony" );
    my $repo = $dist->repo;

    $repo->import_releases(
        releases => $dist->releases_to_import
    );
    cmp_bag $repo->releases, [
        "DCANTRELL/Acme-Pony-1.1.1.tar.gz",
        "DCANTRELL/Acme-Pony-1.1.2.tar.gz"
    ], "releases() after import with git repo";

    # Delete the Git repo
    $repo->git->delete_repo;

    # Use a fresh object to simulate a later run with a Github repo
    # but no Git.
    my $repo2 = new_repo(
        distname        => "Acme-Pony",
        overwrite       => 0
    );
    cmp_bag $repo2->releases, [
        "DCANTRELL/Acme-Pony-1.1.1.tar.gz",
        "DCANTRELL/Acme-Pony-1.1.2.tar.gz"
    ], "releases() with Github but no git repo";
};

done_testing;
