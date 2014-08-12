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
    my $gh = Gitpan::Github->new;
    is $gh->repo_name_on_github("gitpan"), "gitpan";
    is $gh->repo_name_on_github("Foo-Bar"), "Foo-Bar";
    is $gh->repo_name_on_github("Some_Thing"), "Some_Thing";
    is $gh->repo_name_on_github("This::Thât"), "This-Th-t";
    is $gh->repo_name_on_github("Testing-ünicode"), "Testing--nicode";
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
        repo    => rand_distname()."-Ünicode",
    );

    ok !$gh->exists_on_github;
    lives_ok { $gh->delete_repo_if_exists; };

    $gh->create_repo(
        desc            => "Testing Ünicode",
        homepage        => "http://example.com/Ünicode"
    );
    ok $gh->exists_on_github;
    $gh->delete_repo_if_exists;
    ok !$gh->exists_on_github;
}

done_testing();
