#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Git;
use Gitpan::Github;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "prepare_for_commits, no git, no github" => sub {
    my $repo = new_repo;

    ok $repo->prepare_for_commits;
    ok $repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;
    ok $repo->git->is_empty;
    ok !$repo->github->exists_on_github;
};


subtest "prepare_for_commits, git repo, no Github" => sub {
    my $repo = new_repo;

    # Make a git repo.
    my $git = Gitpan::Git->init(
        repo_dir        => $repo->repo_dir,
        distname        => $repo->distname
    );

    # Put a commit in it to make sure we don't blow the repo away
    $git->repo_dir->child("foo")->touch;
    $git->add( "foo" );
    $git->commit( message => "testing" );

    ok $repo->prepare_for_commits;
    ok $repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;
    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok !$repo->github->exists_on_github;
};


subtest "prepare_for_commits, no git repo, have Github" => sub {
    my $repo = new_repo();

    # Make a Github repo.
    my $github = $repo->github;
    $github->create_repo;

    # Put some commits into the Github repo
    # But don't put the git repo where Gitpan::Repo will find it
    my $git = Gitpan::Git->clone(
        url             => $github->remote,
        distname        => $repo->distname
    );
    $git->repo_dir->child("foo")->touch;
    $git->add( "foo" );
    $git->commit( message => "testing" );
    $git->push;

    ok $repo->prepare_for_commits;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok $repo->github->exists_on_github;
};


subtest "prepare_for_commits, Github + Git repos, Git is ahead" => sub {
    my $repo = new_repo();

    # Make a Github repo.
    my $github = $repo->github;
    $github->create_repo;

    # Put a commits into the Github repo
    my $git = Gitpan::Git->clone(
        repo_dir        => $repo->repo_dir,
        url             => $github->remote,
        distname        => $repo->distname
    );
    $git->repo_dir->child("foo")->touch;
    $git->add( "foo" );
    $git->commit( message => "testing" );
    $git->push;

    # Put another commit in the Git repo to get ahead
    $git->repo_dir->child("bar")->touch;
    $git->add( "bar" );
    $git->commit( message => "getting ahead of Github" );

    ok $repo->prepare_for_commits;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("bar");
    ok $repo->github->exists_on_github;

    my $clone = Gitpan::Git->clone(
        url             => $github->remote,
        distname        => $repo->distname
    );
    ok -e $clone->repo_dir->child("foo");
    ok !-e $clone->repo_dir->child("bar");
};


subtest "prepare_for_commits, Github + Git repos, Git is behind" => sub {
    my $repo = new_repo;

    # Make a Github repo.
    my $github = $repo->github;
    $github->create_repo;

    # Put a commit into the Github repo
    my $clone = Gitpan::Git->clone(
        url             => $github->remote,
        distname        => $repo->distname
    );
    $clone->repo_dir->child("foo")->touch;
    $clone->add( "foo" );
    $clone->commit( message => "testing" );
    $clone->push;

    # Clone the Github repo so Repo will see it
    my $git = Gitpan::Git->clone(
        repo_dir        => $repo->repo_dir,
        url             => $github->remote,
        distname        => $repo->distname
    );

    # Put another commit in the Github repo to get ahead
    $clone->repo_dir->child("bar")->touch;
    $clone->add( "bar" );
    $clone->commit( message => "getting ahead of Git" );
    $clone->push;

    ok $repo->prepare_for_commits;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("bar"), "the local git repo pulled";
    ok $repo->github->exists_on_github;
};


subtest "prepare_for_commits, Github + Git repos, diverged" => sub {
    my $repo = new_repo;

    # Make a Github repo.
    my $github = $repo->github;
    $github->create_repo;

    # Repo will not see this
    my $clone = Gitpan::Git->clone(
        url             => $github->remote,
        distname        => $repo->distname
    );

    # This is the one Repo will see
    my $git = Gitpan::Git->clone(
        repo_dir        => $repo->repo_dir,
        url             => $github->remote,
        distname        => $repo->distname
    );

    # Make Github diverge
    $clone->repo_dir->child("bar")->touch;
    $clone->add_all;
    $clone->commit( message => "Github is diverging" );
    $clone->push;

    # And now the one Repo can see diverges
    $git->repo_dir->child("baz")->touch;
    $git->add_all;
    $git->commit( message => "local is diverging" );

    throws_ok {
        $repo->prepare_for_commits;
    } qr{Not possible to fast-forward};
    ok !$repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;
};


done_testing;
