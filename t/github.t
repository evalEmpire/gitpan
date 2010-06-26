#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Gitpan::Github;

my $gh = Gitpan::Github->new;
isa_ok $gh, "Gitpan::Github";
#isa_ok $gh->network, "Gitpan::Github::Network";


# exists_on_github()
{
    ok $gh->exists_on_github( owner => "schwern", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "schwern", repo => "super-python" );
}


# our defaults
{
    is $gh->owner, "gitpan";
    is $gh->login, "gitpan";
}


# is_too_many_requests
{
    ok $gh->is_too_many_requests({ error => "too many requests" });
    ok !$gh->is_too_many_requests({ error => "too many rabbits" });
    ok $gh->is_too_many_requests({ error => ["wibble", "too many requests"] });
}

done_testing();
