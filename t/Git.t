#!/usr/bin/perl

use lib 't/lib';
use perl5i::2;
use Path::Tiny;

use Gitpan::Test;

use Gitpan::Git;

# Simulate a non-configured system as when testing on Travis.
local $ENV{GIT_COMMITTER_NAME} = '';

note "Check the repo was created"; {
    my $Repo_Dir = Path::Tiny->tempdir->realpath;
    my $git = Gitpan::Git->init( repo_dir => $Repo_Dir );
    isa_ok $git, "Gitpan::Git";

    ok -d $Repo_Dir;
    ok -d $Repo_Dir->child(".git");
    is $git->work_tree, $Repo_Dir;

    note "Can we use an existing repo?";
    my $copy = Gitpan::Git->init( repo_dir => $Repo_Dir );
    isa_ok $copy, "Gitpan::Git";
    is $copy->work_tree, $Repo_Dir;
}


note "Test our cleanup routines"; {
SKIP: {
    my $git = Gitpan::Git->init;
    my $hooks_dir = $git->work_tree->child(".git", "hooks");

    skip "No hooks dir" unless -d $hooks_dir;
    skip "No sample hooks" unless [$hooks_dir->children]->first(qr{\.sample$});

    $git->clean;
    ok ![$hooks_dir->children]->first(qr{\.sample$});
}
}

note "Remotes"; {
    my $git = Gitpan::Git->init;

    is_deeply $git->remotes, {};
    $git->change_remote( foo => "http://example.com" );

    is $git->remotes->{foo}{push}, "http://example.com";
    is $git->remote( "foo" ), "http://example.com";
}


note "Remove working copy"; {
    my $git = Gitpan::Git->init;

    my $file = $git->work_tree->child("foo");
    $file->touch;
    ok -e $file;
    $git->remove_working_copy;
    ok !-e $file;
    is_deeply [map { $_->basename } $git->work_tree->children], [".git"];
}


note "revision_exists"; {
    my $git = Gitpan::Git->init;

    $git->work_tree->child("foo")->touch;
    $git->run( add => "foo" );
    $git->run( commit => "-m" => "testing" );

    ok $git->revision_exists("master"),                 "revision_exists - true";
    ok !$git->revision_exists("does_not_exist"),        "  false";
}


note "commit & log"; {
    my $git = Gitpan::Git->init;

    $git->work_tree->child("bar")->touch;
    $git->run( add => "bar" );
    $git->run( commit => "-m" => "testing commit author" );

    my($last_log) = $git->log("-1");
    is $last_log->committer_email, 'schwern+gitpan-test@pobox.com';
    is $last_log->committer_name,  'Gitpan Test';
    is $last_log->author_email,    'schwern+gitpan-test@pobox.com';
    is $last_log->author_name,     'Gitpan Test';
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
    $clone2->run( tag => "some_tag" );

    $clone2->push;
    my($bare_log)   = $bare->log("-1");
    my($clone2_log) = $clone2->log("-1");
    is $bare_log->commit, $clone2_log->commit, "push";

    my @tags = $bare->run( tag => "-l" );
    is_deeply \@tags, ["some_tag"], "pushing tags";
}


note "delete_repo"; {
    my $git = Gitpan::Git->init;
    ok -e $git->work_tree;

    $git->delete_repo;
    ok !-e $git->work_tree;
}


note "rm and add all"; {
    my $origin = Gitpan::Git->init;
    my $clone = Gitpan::Git->clone(
        url => $origin->work_tree.'',
    );

    $origin->work_tree->child("foo")->touch;
    $origin->work_tree->child("bar")->touch;
    $origin->add_all;
    $origin->run(commit => "-m" => "Adding foo and bar");

    $clone->pull;
    ok -e $clone->work_tree->child("foo");
    ok -e $clone->work_tree->child("bar");

    $origin->rm_all;
    $origin->work_tree->child("bar")->touch;
    $origin->work_tree->child("baz")->touch;    
    $origin->add_all;
    $origin->run(commit => "-m" => "Adding bar and baz");

    $clone->pull;
    ok -e $clone->work_tree->child("bar");
    ok -e $clone->work_tree->child("baz");
}


note "Commit release"; {
    my $git = Gitpan::Git->init;

    use Gitpan::Release;
    my $release = Gitpan::Release->new(
        distname        => 'Acme-LookOfDisapproval',
        version         => '0.005',
    );

    $git->work_tree->child("foo")->touch;
    $git->work_tree->child("bar")->touch;
    $git->add_all;
    $git->commit_release($release);

    my($last_commit) = $git->log("-1");
    is $last_commit->author_name,       "Karen Etheridge";
    is $last_commit->author_email,      'ether@cpan.org';
    is $last_commit->committer_name,    'Gitpan Test';
    is $last_commit->committer_email,   'schwern+gitpan-test@pobox.com';
    is $last_commit->author_gmtime,     1382763843;

    my $log_message = $last_commit->message;
    like $log_message, qr{^Import of ETHER/Acme-LookOfDisapproval-0.005 from CPAN}ms;
    like $log_message, qr{^gitpan-cpan-distribution:\s+Acme-LookOfDisapproval}ms;
    like $log_message, qr{^gitpan-cpan-version:\s+0.005}ms;
    like $log_message, qr{^gitpan-cpan-path:\s+ETHER/Acme-LookOfDisapproval-0.005.tar.gz}ms;
    like $log_message, qr{^gitpan-cpan-author:\s+ETHER}ms;
    like $log_message, qr{^gitpan-cpan-maturity:\s+released}ms;
    like $log_message, qr{^gitpan-version:\s+0.005}ms;

    is $git->run("tag", "-l", "cpan_path/*"),      "cpan_path/ETHER/Acme-LookOfDisapproval-0.005.tar.gz";
    is $git->run("tag", "-l", "gitpan_version/*"), "gitpan_version/0.005";
    is $git->run("tag", "-l", "cpan_version/*"),   "cpan_version/0.005";
}

done_testing;
