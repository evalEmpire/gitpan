#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

my $CLASS = 'Gitpan::Repo';

require_ok $CLASS;

subtest "basics" => sub {
    my $repo = $CLASS->new( distname => 'Acme-Pony' );

    ok !$repo->has_github,      "github is created lazily";
};

done_testing;
