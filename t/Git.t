#!/usr/bin/perl

use perl5i::2;
use Path::Class;
use File::Temp qw(tempdir);

use Test::More;

use Gitpan::Git;

# Simulate a non-configured system as when testing on Travis.
local $ENV{GIT_COMMITTER_NAME} = '';

my $Repo_Dir = dir(tempdir( CLEANUP => 1 ))->resolve;
my $git = Gitpan::Git->init( $Repo_Dir );
isa_ok $git, "Gitpan::Git";

# Check the repo was created
{
    ok -d $Repo_Dir;
    ok -d $Repo_Dir->subdir(".git");
    is $git->work_tree, $Repo_Dir;
}


# Can we use an existing repo?
{
    my $copy = Gitpan::Git->init( $Repo_Dir );
    isa_ok $copy, "Gitpan::Git";
    is $copy->work_tree, $Repo_Dir;
}


# Test our cleanup routines
SKIP: {
    my $hooks_dir = $Repo_Dir->subdir(".git", "hooks");

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
    my $file = file( $git->work_tree, "foo" );
    $file->touch;
    ok -e $file;
    $git->remove_working_copy;
    ok !-e $file;
    is_deeply [map { $_->dir_list(-1) } dir( $git->work_tree )->children], [".git"];
}


# revision_exists
{
    file( $git->work_tree, "foo" )->touch;
    $git->run( add => "foo" );
    $git->run( commit => "-m" => "testing" );

    ok $git->revision_exists("master"),                 "revision_exists - true";
    ok !$git->revision_exists("does_not_exist"),        "  false";
}


# commit & log
{
    file( $git->work_tree, "bar" )->touch;
    $git->run( add => "bar" );
    $git->run( commit => "-m" => "testing commit author" );

    my($last_log) = $git->log("-1");
    is $last_log->committer_email, 'schwern+gitpan@pobox.com';
    is $last_log->committer_name,  'Gitpan';
    is $last_log->author_email,    'schwern+gitpan@pobox.com';
    is $last_log->author_name,     'Gitpan';
}


done_testing;
