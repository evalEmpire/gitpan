#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "No github, no git" => sub {
    my $repo = new_repo;

    $repo->sync_with_github;

    ok $repo->is_synced_with_github;
    ok !$repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;

    ok !$repo->have_git_repo;
    ok !$repo->have_github_repo;
};


subtest "Git, no Github" => sub {
    my $repo = new_repo;

    my $git = $repo->git;

    $repo->sync_with_github;

    ok $repo->is_synced_with_github;
    ok !$repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;

    ok $repo->have_git_repo;
    ok !$repo->have_github_repo;
};


subtest "No Git, have Github" => sub {
    my $repo = new_repo;

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

    ok $repo->sync_with_github;

    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok $repo->is_synced_with_github;

    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok $repo->github->exists_on_github;
    ok $repo->are_git_and_github_on_the_same_commit;

    lives_ok { $repo->git->push; };
    ok $repo->are_git_and_github_on_the_same_commit;
};


subtest "Github & Git, Git is ahead" => sub {
    my $repo = new_repo;

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

    ok $repo->sync_with_github;

    ok $repo->is_synced_with_github;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;

    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok $repo->github->exists_on_github;
    ok !$repo->are_git_and_github_on_the_same_commit;

    lives_ok { $repo->git->push; };
    ok $repo->are_git_and_github_on_the_same_commit;
};


subtest "Github + Git repos, Git is behind" => sub {
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

    ok $repo->sync_with_github;

    ok $repo->is_synced_with_github;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;

    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok -e $repo->repo_dir->child("bar");
    ok $repo->github->exists_on_github;
    ok $repo->are_git_and_github_on_the_same_commit;

    lives_ok { $repo->git->push; };
    ok $repo->are_git_and_github_on_the_same_commit;
};


subtest "Github + Git repos, diverged" => sub {
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
        $repo->sync_with_github;
    } qr{Not possible to fast-forward};

    ok !$repo->is_synced_with_github;
    ok !$repo->is_prepared_for_commits;
    ok !$repo->is_prepared_for_push;

    ok !$repo->are_git_and_github_on_the_same_commit;
};


done_testing;
