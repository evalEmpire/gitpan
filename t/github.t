#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Gitpan::Github;

my $gh = Gitpan::Github->new;

{
    ok $gh->exists_on_github( owner => "schwern", repo => "gitpan" );
    ok !$gh->exists_on_github( owner => "schwern", repo => "super-python" );
}


done_testing();
