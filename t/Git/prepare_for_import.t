#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Git;

subtest "prepare_for_import on an empty repository" => sub {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    lives_ok { $git->prepare_for_import; }
      "Doesn't choke when there's no files";

    # Untracked file
    $git->repo_dir->child("foo")->touch;

    # Staged file
    $git->repo_dir->child("bar")->touch;
    $git->add( "bar");

    $git->prepare_for_import;
    pass("works on a repo with no commits");

    ok !-e $git->repo_dir->child("foo"), "deletes uncommitted files";
    ok !-e $git->repo_dir->child("bar"), "restores unstaged state";

    cmp_deeply [$git->status], [], "staging is empty";
};


subtest "prepare_for_import on a non-empty repository" => sub {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    my $foo = $git->repo_dir->child("foo");
    my $bar = $git->repo_dir->child("bar");

    # Make the repository non-empty
    $foo->touch;
    $bar->spew("first commit");
    $git->add_all;
    $git->commit( message => "first commit" );

    is $git->current_branch, "master";

    # Change to a different branch
    $git->run( "branch", "something" );
    $git->run_quiet( "checkout", "something" );

    is $git->current_branch, "something";

    # Unstaged change
    $foo->append("Something\nSomething\n");

    # Staged change
    $bar->append("Something else");
    $git->add("bar");

    # Untracked file
    $git->repo_dir->child("untracked")->touch;

    $git->prepare_for_import;

    is $git->current_branch, "master", "branch set to master";
    ok !-e $git->repo_dir->child("untracked"), "untracked files deleted";

    ok -e $foo;
    ok -e $bar;
    is $foo->slurp, "";
    is $bar->slurp, "first commit";

    cmp_deeply [$git->status], [], "staging is empty";
};

done_testing;
