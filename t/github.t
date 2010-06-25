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
    is  $gh->do_with_backoff( times => 10, code => sub { ++$i }, check => sub { $_[1] > 2 } ), 3;
    ok !$gh->do_with_backoff( times => 2,  code => sub { 42 },   check => sub { 0 } );
}

done_testing();
