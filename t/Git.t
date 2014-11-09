#!/usr/bin/perl

use lib 't/lib';
use Gitpan::perl5i;
use Path::Tiny;

use Gitpan::Test;

use Gitpan::Git;

note "Check the repo was created"; {
    my $Repo_Dir = Path::Tiny->tempdir->realpath;
    my $git = Gitpan::Git->init(
        distname => "Foo-Bar",
        repo_dir => $Repo_Dir
    );
    isa_ok $git, "Gitpan::Git";

    ok $git->is_empty;

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


note "new_or_clone"; {
    my $origin = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    $origin->repo_dir->child("foo")->touch;
    $origin->add( "foo" );
    $origin->commit( message => "testing clone" );

    note "Repo dir does not exist."; {
        my $tempdir = Path::Tiny->tempdir;

        # This will clone.
        my $git = Gitpan::Git->new_or_clone(
            distname    => "Foo-Bar",
            url         => $origin->repo_dir.'',
            repo_dir    => $tempdir->child("foo")
        );
        ok -e $git->repo_dir->child("foo");
    }

    note "Repo dir exists, but there's no repository."; {
        my $tempdir = Path::Tiny->tempdir;

        # This will clone.
        my $git = Gitpan::Git->new_or_clone(
            distname        => "Foo-Bar",
            url             => $origin->repo_dir.'',
            repo_dir        => $tempdir
        );
        ok -e $git->repo_dir->child("foo");
    }

    note "Repo dir and repository exists, but the remote is wrong"; {
        my $tempdir = Path::Tiny->tempdir;
        Gitpan::Git->init(
            distname    => "Foo-Bar",
            repo_dir    => $tempdir
        );

        my $git = Gitpan::Git->new_or_clone(
            distname    => "Foo-Bar",
            url             => $origin->repo_dir.'',
            repo_dir        => $tempdir
        );
        ok -e $git->repo_dir->child("foo");
    }
}


note "Remotes"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    is_deeply $git->remotes, {};

    ok !$git->remote("foo");

    $git->change_remote( foo => "http://example.com" );

    is $git->remote( "foo" ),         "http://example.com";
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
    $git->add( "foo" );
    $git->commit( message => "testing" );

    $git->tag("some_tag");

    note "revision_exists on a branch";
    my $master = $git->revision_exists("master");
    isa_ok $master, "Git::Raw::Branch";
    is $master->target->id, $git->head->target->id;

    note "revision_exists on a SHA";
    my $head = $git->revision_exists($git->head->target->id);
    isa_ok $head, "Git::Raw::Commit";
    is $head->id, $git->head->target->id;

    note "revision_exists on a lightweight tag";
    my $tag = $git->revision_exists("some_tag");
    isa_ok $tag, "Git::Raw::Reference";
    is $tag->target->id, $git->head->target->id;

    ok !$git->revision_exists("does_not_exist"), "something which does not exist";
}


note "commit & log"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    $git->repo_dir->child("bar")->touch;
    $git->add( "bar" );
    $git->commit( message => "testing commit author" );

    ok !$git->is_empty;
    is $git->head->shorthand, "master";

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
    $origin->add( "foo" );
    $origin->commit( message => "testing clone" );

    my $clone = Gitpan::Git->clone(
        url             => $origin->repo_dir.'',
        distname        => "Foo-Bar"
    );
    is $clone->current_branch, $origin->current_branch;

    ok -e $clone->repo_dir->child("foo"), "working directory cloned";

    my($origin_log1) = $origin->log("-1");
    my($clone_log1)  = $clone->log("-1");
    is $origin_log1->commit, $clone_log1->commit, "commit ids cloned";

    # Test pull
    $origin->repo_dir->child("bar")->touch;
    $origin->add( "bar" );
    $origin->commit( message => "adding bar" );

    $clone->pull;

    ok -e $clone->repo_dir->child("bar"), "pulled new file";

    my($origin_log2) = $origin->log("-1");
    my($clone_log2)  = $clone->log("-1");
    is $origin_log2->commit, $clone_log2->commit, "commit ids pulled";

    # Test push
    my $bare = Gitpan::Git->clone(
        url      => $origin->repo_dir.'',
        distname => "Foo-Bar",
        options  => { bare => 1 }
    );
    my $clone2 = Gitpan::Git->clone(
        url      => $bare->git_dir.'',
        distname => "Foo-Bar"
    );
    $clone2->repo_dir->child("baz")->touch;
    $clone2->add( "baz" );
    $clone2->commit( message => "adding baz" );
    $clone2->tag( "some_tag" );

    $clone2->push;
    my($bare_log)   = $bare->log("-1");
    my($clone2_log) = $clone2->log("-1");
    is $bare_log->commit, $clone2_log->commit, "push";

    my $tags = $bare->list_tags;
    is_deeply $tags, ["some_tag"], "pushing tags";
}


subtest "push --ff-only" => sub {
    my $origin = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    $origin->repo_dir->child("foo")->touch;
    $origin->add( "foo" );
    $origin->commit( message => "testing clone" );

    my $clone = Gitpan::Git->clone(
        url             => $origin->repo_dir.'',
        distname        => "Foo-Bar"
    );

    # Make the clone diverge
    $clone->repo_dir->child("bar")->touch;
    $clone->add_all;
    $clone->commit( message => "clone is diverging" );

    # And now origin
    $origin->repo_dir->child("baz")->touch;
    $origin->add_all;
    $origin->commit( message => "origin is diverging" );

    throws_ok {
        $clone->pull( ff_only => 1 );
    } qr/Not possible to fast-forward/;
};


note "delete_repo"; {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );
    ok -e $git->repo_dir;

    $git->delete_repo;
    ok !-e $git->repo_dir;
}


subtest "add_all with .gitignore" => sub {
    my $git = Gitpan::Git->init(
        distname        => "Foo-Bar"
    );

    my $gitignore = $git->repo_dir->child(".gitignore");
    my $foo = $git->repo_dir->child("foo");

    $gitignore->append("foo\n");
    $foo->touch;

    cmp_deeply [map { $_->path1 } grep { $_->ignored } $git->status("--ignored")], ["foo"];
    $git->add_all;
    cmp_deeply [grep { $_->ignored } $git->status("--ignored")], [];

    $git->commit( message => "first commit");

    cmp_deeply [grep { $_->ignored } $git->status("--ignored")], [];
};


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
    $origin->commit( message => "Adding foo and bar");

    $clone->pull;
    ok -e $clone->repo_dir->child("foo");
    ok -e $clone->repo_dir->child("bar");

    $origin->rm_all;
    cmp_deeply [map { $_->relative($origin->repo_dir).'' } $origin->repo_dir->children],
               [".git"];

    $origin->repo_dir->child("bar")->touch;
    $origin->repo_dir->child("baz")->touch;    
    $origin->add_all;
    $origin->commit( message => "Adding bar and baz");

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

    cmp_deeply $git->cpan_paths,      ["ETHER/Acme-LookOfDisapproval-0.005.tar.gz"];
    cmp_deeply $git->gitpan_versions, ["0.005"];
    cmp_deeply $git->cpan_versions,   ["0.005"];
    ok $git->get_tag("stable");
    ok $git->get_tag("ETHER");
}


note "Commit release, no author name"; {
    my $git = Gitpan::Git->init(
        distname        => "Acme-Maybe"
    );

    use Gitpan::Release;
    my $release = Gitpan::Release->new(
        distname        => 'Acme-Maybe',
        version         => '0.01',
    );

    $git->repo_dir->child("foo")->touch;
    $git->repo_dir->child("bar")->touch;
    $git->add_all;
    $git->commit_release($release);

    my($last_commit) = $git->log("-1");
    is $last_commit->author_name,       "MAXA";
    is $last_commit->author_email,      'maxa@cpan.org';
}


# Releases with no version would make a tag called "cpan_version"
# instead of cpan_version/$version and this would make the next
# release unable to tag.
note "tag_release, no version"; {
    my $git = Gitpan::Git->init(
        distname        => "Acme-Blarghy-McBlarghBlargh"
    );

    use Gitpan::Release;
    my $release0 = Gitpan::Release->new(
        distname        => 'Acme-Blarghy-McBlarghBlargh',
        version         => '',
    );

    $git->repo_dir->child("foo")->touch;
    $git->repo_dir->child("bar")->touch;
    $git->add_all;
    $git->commit_release($release0);

    my $release2 = Gitpan::Release->new(
        distname        => 'Acme-Blarghy-McBlarghBlargh',
        version         => '0.002',
    );
    $git->repo_dir->child("foo")->spew("stuff\n");
    $git->add_all;
    $git->commit_release($release2);

    cmp_deeply scalar $git->cpan_paths->sort,
               [sort 
                     "DHOSS/Acme-Blarghy-McBlarghBlargh.tar.gz",
                     "DHOSS/Acme-Blarghy-McBlarghBlargh-0.002.tar.gz"
               ];
    cmp_deeply $git->gitpan_versions, ['0.002'];
    cmp_deeply $git->cpan_versions,   ['0.002'];
    ok $git->get_tag("stable");
    ok $git->get_tag("DHOSS");
}


done_testing;
