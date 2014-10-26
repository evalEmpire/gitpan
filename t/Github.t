#!/usr/bin/perl

use lib 't/lib';
use Gitpan::perl5i;

use Gitpan::Test;

use Gitpan::Github;

func rand_distname {
    my @names;

    my @letters = ("a".."z","A".."Z");
    for (0..rand(4)+1) {
        push @names, join "", map { $letters[rand @letters] } 1..rand(20);
    }

    return @names->join("-");
}

note "repo_name_on_github()"; {
    my %tests = (
        "gitpan"                => "gitpan",
        "Foo-Bar"               => "Foo-Bar",
        "Some_Thing"            => "Some_Thing",
        "This::Thât"            => "This-Th-t",
        "Testing-ünicode"       => "Testing--nicode",
        "bpd.PW44"              => "bpd.PW44",
        "perl-5.005_02+apache1.3.3+modperl" => "perl-5.005_02-apache1.3.3-modperl",
    );

    %tests->each(func($have, $want) {
        my $gh = Gitpan::Github->new( repo => $have );
        is $gh->repo_name_on_github, $want, "$have -> $want";
    });
}


note "get_repo_info()"; {
    my $gh = Gitpan::Github->new( repo => "super-python", owner => "evalEmpire" );
    ok !$gh->get_repo_info;

    $gh = Gitpan::Github->new( owner => "evalEmpire", repo => "gitpan" );
    is $gh->get_repo_info->{name}, 'gitpan';

    $gh = Gitpan::Github->new( owner => "evalEmpire", repo => "GITPAN" );
    is $gh->get_repo_info->{name}, 'gitpan';
}


note "exists_on_github()"; {
    my $gh = Gitpan::Github->new( owner => "evalEmpire", repo => "gitpan" );
    ok $gh->exists_on_github;

    $gh = Gitpan::Github->new( owner => "evalEmpire", repo => "super-python" );
    ok !$gh->exists_on_github;

    $gh = Gitpan::Github->new( repo => "i-do-not-exist-pretty-sure" ); 
    ok !$gh->exists_on_github;
}


note "remote"; {
    my $gh = Gitpan::Github->new( repo => "gitpan" );

    like $gh->remote(), qr{^https://.*?:\@github.com/gitpan-test/gitpan.git};
}


note "create and delete repos"; {
    my $gh = Gitpan::Github->new(
        repo    => rand_distname()."-Ünicode",
    );

    ok !$gh->exists_on_github;
    lives_ok { $gh->delete_repo_if_exists; };

    $gh->create_repo(
        desc            => "Testing Ünicode",
        homepage        => "http://example.com/Ünicode"
    );
    ok $gh->_exists_on_github_cache, "create sets the exists cache";
    ok $gh->exists_on_github;

    $gh->delete_repo_if_exists;

    ok !$gh->_exists_on_github_cache, "delete unsets the exists cache";
    ok !$gh->exists_on_github;
}


subtest "branch_info" => sub {
    my $gh = Gitpan::Github->new(
        repo => rand_distname()
    );
    $gh->create_repo;
    note "Dist log: @{[$gh->dist_log_file]}";

    require Gitpan::Git;
    my $git = Gitpan::Git->clone(
        url             => $gh->remote,
        distname        => $gh->distname
    );
    $git->repo_dir->child("foo")->touch;
    $git->add_all;
    $git->commit( message => "for testing" );

    # Push at the same time we're trying to get branch info
    my $child = child {
        note "Trying push";
        $git->push;
        note "push done";
    };
    my $info = $gh->branch_info;
    $child->wait;

    is $info->{commit}{sha}, $git->head->target->id, "git and Github match after push";
};

done_testing();
