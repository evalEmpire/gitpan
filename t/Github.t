#!/usr/bin/perl

use lib 't/lib';
use perl5i::2;
use Method::Signatures;

use Gitpan::Test;

use Gitpan::Github;

func rand_distname {
    my @names;

    my @letters = ("a".."z","A".."Z", "ñ");
    for (0..rand(4)+1) {
        push @names, join "", map { $letters[rand @letters] } 1..rand(20);
    }

    return @names->join("-");
}

note "exists_on_github()"; {
    my $gh = Gitpan::Github->new;

    ok $gh->exists_on_github( owner => "evalEmpire", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "evalEmpire", repo => "super-python" );
    ok !$gh->exists_on_github( repo => "i-do-not-exist-pretty-sure" );
}


note "remote"; {
    my $gh = Gitpan::Github->new;

    like $gh->remote( repo => "gitpan" ),
         qr{^https://.*?:\@github.com/gitpan-test/gitpan.git};
}


note "create and delete repos"; {
    my $gh = Gitpan::Github->new(
        repo    => rand_distname(),
    );

    ok !$gh->exists_on_github;
    lives_ok { $gh->delete_repo_if_exists; };

    $gh->create_repo;
    ok $gh->exists_on_github;
    $gh->delete_repo_if_exists;
    ok !$gh->exists_on_github;
}

done_testing();
