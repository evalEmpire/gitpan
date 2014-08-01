#!/usr/bin/perl

use lib 't/lib';
use perl5i::2;
use Gitpan::Test;

use Gitpan::Github;

my $gh = Gitpan::Github->new;
isa_ok $gh, "Gitpan::Github";


note "exists_on_github()"; {
    ok $gh->exists_on_github( owner => "evalEmpire", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "evalEmpire", repo => "super-python" );
    ok !$gh->exists_on_github( repo => "i-do-not-exist-pretty-sure" );
}


note "remote"; {
    is $gh->remote( repo => "gitpan" ), "git\@github.com:gitpan-test/gitpan.git";
}

done_testing();
