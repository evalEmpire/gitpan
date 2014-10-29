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


done_testing;
