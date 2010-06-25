#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Gitpan::Repo;

my $repo = Gitpan::Repo->new( distname => "Foo-Bar" );
isa_ok $repo, "Gitpan::Repo";

done_testing;
