#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Git;
use Gitpan::Github;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "prepare_for_push, no git, no github" => sub {
    my $repo = new_repo;

    ok $repo->prepare_for_push;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok $repo->git->is_empty;
    ok $repo->github->exists_on_github;

    # Try to push a commit
    $repo->git->repo_dir->child("foo");
    $repo->git->add_all;
    $repo->git->commit( message => "testing commit" );

    lives_ok { $repo->git->push; };
    ok $repo->are_git_and_github_on_the_same_commit;
};


subtest "prepare_for_push, git repo, no Github" => sub {
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

    ok $repo->prepare_for_push;
    ok $repo->is_prepared_for_commits;
    ok $repo->is_prepared_for_push;
    ok !$repo->git->is_empty;
    ok -e $repo->repo_dir->child("foo");
    ok $repo->github->exists_on_github;

    lives_ok { $repo->git->push; };
    ok $repo->are_git_and_github_on_the_same_commit;
};


done_testing;
