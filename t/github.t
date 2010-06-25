#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Gitpan::Github;

my $gh = Gitpan::Github->new;

# exists_on_github()
{
    ok $gh->exists_on_github( owner => "schwern", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "schwern", repo => "super-python" );
}


# do_with_backoff()
{
    my $i = 0;
    is  $gh->do_with_backoff( times => 5, code => sub { ++$i }, check => sub { $_[1] > 2 } ), 3;
    ok !$gh->do_with_backoff( times => 2, code => sub { 42 },   check => sub { 0 } );
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
