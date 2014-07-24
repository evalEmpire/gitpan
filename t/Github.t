#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Gitpan::Github;

my $gh = Gitpan::Github->new;
isa_ok $gh, "Gitpan::Github";


# exists_on_github()
{
    ok $gh->exists_on_github( owner => "evalEmpire", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "evalEmpire", repo => "super-python" );
}


# remote
{
    is $gh->remote( repo => "gitpan" ), "git\@github.com:gitpan/gitpan.git";
}

done_testing();
