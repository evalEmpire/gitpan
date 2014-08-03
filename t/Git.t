#!/usr/bin/perl

use perl5i::2;
use Path::Tiny;

use Test::More;

use Gitpan::Git;

# Simulate a non-configured system as when testing on Travis.
local $ENV{GIT_COMMITTER_NAME} = '';

my $Repo_Dir = Path::Tiny->tempdir->realpath;
my $git = Gitpan::Git->init( repo_dir => $Repo_Dir );
isa_ok $git, "Gitpan::Git";

# Check the repo was created
{
    ok -d $Repo_Dir;
    ok -d $Repo_Dir->child(".git");
    is $git->work_tree, $Repo_Dir;
}


# Can we use an existing repo?
{
    my $copy = Gitpan::Git->init( repo_dir => $Repo_Dir );
    isa_ok $copy, "Gitpan::Git";
    is $copy->work_tree, $Repo_Dir;
}


# Test our cleanup routines
SKIP: {
    my $hooks_dir = $Repo_Dir->child(".git", "hooks");

    skip "No hooks dir" unless -d $hooks_dir;
    skip "No sample hooks" unless [$hooks_dir->children]->first(qr{\.sample$});

    $git->clean;
    ok ![$hooks_dir->children]->first(qr{\.sample$});
}


# Remotes
{
    is_deeply $git->remotes, {};
    $git->change_remote( foo => "http://example.com" );

    is $git->remotes->{foo}{push}, "http://example.com";
    is $git->remote( "foo" ), "http://example.com";
}


# Remove working copy
{
    my $file = $git->work_tree->child("foo");
    $file->touch;
    ok -e $file;
    $git->remove_working_copy;
    ok !-e $file;
    is_deeply [map { $_->basename } $git->work_tree->children], [".git"];
}


# revision_exists
{
    $git->work_tree->child("foo")->touch;
    $git->run( add => "foo" );
    $git->run( commit => "-m" => "testing" );

    ok $git->revision_exists("master"),                 "revision_exists - true";
    ok !$git->revision_exists("does_not_exist"),        "  false";
}


# commit & log
{
    $git->work_tree->child("bar")->touch;
    $git->run( add => "bar" );
    $git->run( commit => "-m" => "testing commit author" );

    my($last_log) = $git->log("-1");
    is $last_log->committer_email, 'schwern+gitpan@pobox.com';
    is $last_log->committer_name,  'Gitpan';
    is $last_log->author_email,    'schwern+gitpan@pobox.com';
    is $last_log->author_name,     'Gitpan';
}


note "clone, push, pull"; {
    my $origin = Gitpan::Git->init();
    $origin->work_tree->child("foo")->touch;
    $origin->run( add => "foo" );
    $origin->run( commit => "-m" => "testing clone" );

    my $clone = Gitpan::Git->clone(
        url => $origin->work_tree.'',
    );

    ok -e $clone->work_tree->child("foo"), "working directory cloned";

    my($origin_log1) = $origin->log("-1");
    my($clone_log1)  = $clone->log("-1");
    is $origin_log1->commit, $clone_log1->commit, "commit ids cloned";

    # Test pull
    $origin->work_tree->child("bar")->touch;
    $origin->run( add => "bar" );
    $origin->run( commit => "-m" => "adding bar" );

    $clone->pull;

    ok -e $clone->work_tree->child("bar"), "pulled new file";

    my($origin_log2) = $origin->log("-1");
    my($clone_log2)  = $clone->log("-1");
    is $origin_log2->commit, $clone_log2->commit, "commit ids pulled";

    # Test push
    my $bare = Gitpan::Git->clone(
        url      => $origin->work_tree.'',
        options  => [ "--bare" ]
    );
    my $clone2 = Gitpan::Git->clone(
        url      => $bare->git_dir.'',
    );
    $clone2->work_tree->child("baz")->touch;
    $clone2->run( add => "baz" );
    $clone2->run( commit => "-m" => "adding baz" );

    $clone2->push;
    my($bare_log)   = $bare->log("-1");
    my($clone2_log) = $clone2->log("-1");
    is $bare_log->commit, $clone2_log->commit, "push";
}


note "delete_repo"; {
    my $git = Gitpan::Git->init;
    ok -e $git->work_tree;

    $git->delete_repo;
    ok !-e $git->work_tree;
}

done_testing;
