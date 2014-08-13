#!/usr/bin/perl

use lib 't/lib';
use Gitpan::perl5i;
use Path::Tiny;

use Gitpan::Test;

use Gitpan::Git;

# Simulate a non-configured system as when testing on Travis.
local $ENV{GIT_COMMITTER_NAME} = '';

note "Check the repo was created"; {
    my $Repo_Dir = Path::Tiny->tempdir->realpath;
    my $git = Gitpan::Git->init(
        distname => "Foo-Bar",
        repo_dir => $Repo_Dir
    );
    isa_ok $git, "Gitpan::Git";

    ok -d $Repo_Dir;
    ok -d $Repo_Dir->child(".git");
    is $git->repo_dir, $Repo_Dir;

    note "Can we use an existing repo?";
    my $copy = Gitpan::Git->init(
        distname => "Foo-Bar",
        repo_dir => $Repo_Dir
    );
    isa_ok $copy, "Gitpan::Git";
    is $copy->repo_dir, $Repo_Dir;
}


note "Test our cleanup routines"; {
SKIP: {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    my $hooks_dir = $git->repo_dir->child(".git", "hooks");

    skip "No hooks dir" unless -d $hooks_dir;
    skip "No sample hooks" unless [$hooks_dir->children]->first(qr{\.sample$});

    $git->clean;
    ok ![$hooks_dir->children]->first(qr{\.sample$});
}
}

note "Remotes"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    is_deeply $git->remotes, {};
    $git->change_remote( foo => "http://example.com" );

    is $git->remotes->{foo}{push}, "http://example.com";
    is $git->remote( "foo" ), "http://example.com";
}


note "Remove working copy"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    my $file = $git->repo_dir->child("foo");
    $file->touch;
    ok -e $file;
    $git->remove_working_copy;
    ok !-e $file;
    is_deeply [map { $_->basename } $git->repo_dir->children], [".git"];
}


note "revision_exists"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    $git->repo_dir->child("foo")->touch;
    $git->run( add => "foo" );
    $git->run( commit => "-m" => "testing" );

    ok $git->revision_exists("master"),                 "revision_exists - true";
    ok !$git->revision_exists("does_not_exist"),        "  false";
}


note "commit & log"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    $git->repo_dir->child("bar")->touch;
    $git->run( add => "bar" );
    $git->run( commit => "-m" => "testing commit author" );

    my($last_log) = $git->log("-1");
    is $last_log->committer_email, 'schwern+gitpan-test@pobox.com';
    is $last_log->committer_name,  'Gitpan Test';
    is $last_log->author_email,    'schwern+gitpan-test@pobox.com';
    is $last_log->author_name,     'Gitpan Test';
}


note "clone, push, pull"; {
    my $origin = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    $origin->repo_dir->child("foo")->touch;
    $origin->run( add => "foo" );
    $origin->run( commit => "-m" => "testing clone" );

    my $clone = Gitpan::Git->clone(
        url             => $origin->repo_dir.'',
        distname        => "Foo-Bar"
    );

    ok -e $clone->repo_dir->child("foo"), "working directory cloned";

    my($origin_log1) = $origin->log("-1");
    my($clone_log1)  = $clone->log("-1");
    is $origin_log1->commit, $clone_log1->commit, "commit ids cloned";

    # Test pull
    $origin->repo_dir->child("bar")->touch;
    $origin->run( add => "bar" );
    $origin->run( commit => "-m" => "adding bar" );

    $clone->pull;

    ok -e $clone->repo_dir->child("bar"), "pulled new file";

    my($origin_log2) = $origin->log("-1");
    my($clone_log2)  = $clone->log("-1");
    is $origin_log2->commit, $clone_log2->commit, "commit ids pulled";

    # Test push
    my $bare = Gitpan::Git->clone(
        url      => $origin->repo_dir.'',
        distname => "Foo-Bar",
        options  => [ "--bare" ]
    );
    my $clone2 = Gitpan::Git->clone(
        url      => $bare->git_dir.'',
        distname => "Foo-Bar"
    );
    $clone2->repo_dir->child("baz")->touch;
    $clone2->run( add => "baz" );
    $clone2->run( commit => "-m" => "adding baz" );
    $clone2->tag( "some_tag" );

    $clone2->push;
    my($bare_log)   = $bare->log("-1");
    my($clone2_log) = $clone2->log("-1");
    is $bare_log->commit, $clone2_log->commit, "push";

    my @tags = $bare->list_tags;
    is_deeply \@tags, ["some_tag"], "pushing tags";
}


note "delete_repo"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    ok -e $git->repo_dir;

    $git->delete_repo;
    ok !-e $git->repo_dir;
}


note "rm and add all"; {
    my $origin = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    my $clone = Gitpan::Git->clone(
        url             => $origin->repo_dir.'',
        distname        => "Foo-Bar"
    );

    $origin->repo_dir->child("foo")->touch;
    $origin->repo_dir->child("bar")->touch;
    $origin->add_all;
    $origin->run(commit => "-m" => "Adding foo and bar");

    $clone->pull;
    ok -e $clone->repo_dir->child("foo");
    ok -e $clone->repo_dir->child("bar");

    $origin->rm_all;
    $origin->repo_dir->child("bar")->touch;
    $origin->repo_dir->child("baz")->touch;    
    $origin->add_all;
    $origin->run(commit => "-m" => "Adding bar and baz");

    $clone->pull;
    ok -e $clone->repo_dir->child("bar");
    ok -e $clone->repo_dir->child("baz");
}


note "ref_safe_version"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    is $git->ref_safe_version(".1"),   "0.1";
}


note "make_ref_safe"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    my %refs = (
        # 6. They cannot begin or end with a slash / or contain multiple consecutive
        #    slashes.
        '/foo//bar/'            => 'foo/bar',

        # 1. no slash-separated component can begin with a dot .
        'foo/.bar.lock/baz'     => 'foo/-bar-/baz',

        # 3. They cannot have two consecutive dots
        'foo..bar...baz'        => 'foo.bar.baz',

        # 8. They cannot contain a sequence @{
        'foo@{bar'              => 'foo-bar',

        # 4. They cannot have ASCII control characters (i.e. bytes whose values
        #    are lower than \040, or \177 DEL), space, tilde ~, caret ^, or
        #    colon : anywhere.
        # 5. They cannot have question-mark ?, asterisk *, or open bracket [ anywhere
        # 9. They cannot be the single character @
        # 10. They cannot contain a \
        qq{1\a2\x{7f}3\a4 5\n6\t7~8^9:10?11*12[13\@14\\15}
                                => '1-2-3-4-5-6-7-8-9-10-11-12-13-14-15',

        # 7. They cannot end with a dot
        'foo/bar.'              => 'foo/bar-'
    );

    %refs->each(func($have, $want) {
        is $git->make_ref_safe($have), $want or diag "make_ref_safe($have)";
    });
}


note "maturity2tag"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    is $git->maturity2tag("released"),  "stable";
    is $git->maturity2tag("developer"), "alpha";
    is $git->maturity2tag("blah"),      "blah";
}

note "Commit release"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    use Gitpan::Release;
    my $release = Gitpan::Release->new(
        distname        => 'Acme-LookOfDisapproval',
        version         => '0.005',
    );

    $git->repo_dir->child("foo")->touch;
    $git->repo_dir->child("bar")->touch;
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

    is $git->list_tags(patterns => ["cpan_path/*"]),
      "cpan_path/ETHER/Acme-LookOfDisapproval-0.005.tar.gz";
    is $git->list_tags(patterns => ["gitpan_version/*"]),
      "gitpan_version/0.005";
    is $git->list_tags(patterns => ["cpan_version/*"]),
      "cpan_version/0.005";
    is $git->list_tags(patterns => ["stable"]), "stable";
    is $git->list_tags(patterns => ["ETHER"]),  "ETHER";
}

done_testing;
