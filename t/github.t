#!/usr/bin/perl

use strict;
use warnings;

use lib 'inc';

use Test::More;

use Gitpan::Github;

my $gh = Gitpan::Github->new;
isa_ok $gh, "Gitpan::Github";


# exists_on_github()
{
    ok $gh->exists_on_github( owner => "schwern", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "schwern", repo => "super-python" );
}


# remote
{
    is $gh->remote( repo => "gitpan" ), "git\@github-gitpan:gitpan/gitpan.git";
}

done_testing();
