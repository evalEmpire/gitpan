#!/usr/bin/perl

use strict;
use warnings;

use Path::Class;
use Test::More;

use Gitpan::Repo;

my $repo = Gitpan::Repo->new( distname => "Foo-Bar" );
isa_ok $repo, "Gitpan::Repo";

is $repo->distname, "Foo-Bar";
is $repo->directory, dir("Foo-Bar")->absolute;

done_testing;
