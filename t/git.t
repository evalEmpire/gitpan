#!/usr/bin/perl

use perl5i::2;
use Path::Class;
use File::Temp qw(tempdir);

use Test::More;

use Gitpan::Git;

my $Repo_Dir = dir(tempdir( CLEANUP => 1 ))->resolve;
my $git = Gitpan::Git->create( init => $Repo_Dir );
isa_ok $git, "Gitpan::Git";

# Check the repo was created
{
    ok -d $Repo_Dir;
    ok -d $Repo_Dir->subdir(".git");
    is $git->wc_path, $Repo_Dir;
}


# Can we use an existing repo?
{
    my $copy = Gitpan::Git->create( init => $Repo_Dir );
    isa_ok $copy, "Gitpan::Git";
    is $copy->wc_path, $Repo_Dir;
}


# Test our cleanup routines
SKIP: {
    my $hooks_dir = $Repo_Dir->subdir(".git", "hooks");

    skip "No hooks dir" unless -d $hooks_dir;
    skip "No sample hooks" unless [$hooks_dir->children]->first(qr{\.sample$});

    $git->clean;
    ok ![$hooks_dir->children]->first(qr{\.sample$});
}

done_testing;
