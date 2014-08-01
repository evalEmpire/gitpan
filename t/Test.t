#!/usr/bin/env perl

use lib 't/lib';
use perl5i::2;
use Gitpan::Test;

note "Using test config"; {
    use Gitpan::ConfigFile;
    my $config_file = Gitpan::ConfigFile->new;
    my $config = $config_file->config;

    ok $config_file->is_test;
    is $config->github_owner, 'gitpan-test';
}

done_testing;
