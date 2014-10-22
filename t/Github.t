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
    my $gh = Gitpan::Github->new( repo => "Foo-Bar" );

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
        is $gh->repo_name_on_github($have), $want, "$have -> $want";
    });
}


note "get_repo_info()"; {
    my $gh = Gitpan::Github->new( repo => "whatever" );
    ok !$gh->get_repo_info( owner => "evalEmpire", repo => "super-python" );

    my $repo = $gh->get_repo_info( owner => "evalEmpire", repo => "gitpan" );
    is $repo->{name}, 'gitpan';

    $repo = $gh->get_repo_info( owner => "evalEmpire", repo => "GITPAN" );
    is $repo->{name}, 'gitpan';
}


note "exists_on_github()"; {
    my $gh = Gitpan::Github->new( repo => "Foo-Bar" );

    ok $gh->exists_on_github( owner => "evalEmpire", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "evalEmpire", repo => "super-python" );
    ok !$gh->exists_on_github( repo => "i-do-not-exist-pretty-sure" );
}


note "remote"; {
    my $gh = Gitpan::Github->new( repo => "Foo-Bar" );

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
