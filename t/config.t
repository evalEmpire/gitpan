#!/usr/bin/env perl

use perl5i::2;
use Test::Most;
use Path::Class;
use YAML::XS qw(DumpFile);

my $CLASS = 'Gitpan::Config';
require_ok $CLASS;

subtest defaults => sub {
    my $config = new_ok $CLASS;

    ok $config->is_test;
    is $config->config_filename, ".gitpan";
    is_deeply $config->search_dirs, [".", $ENV{HOME}];
    isa_ok $config->config, 'HASH', "config should always return something";
    is_deeply $config->use_overlays, ["test"];
} or BAIL_OUT("config didn't pass basic tests, this is bad");


subtest read_config => sub {
    my $tempdir = Path::Class::tempdir;
    my $config_file  = $tempdir->file("test.gitpan");

    my $config_data = {
        github          => { token => "123abc" },
        overlays        => { foo => { github => { token => "deadbeef" } } }
    };
    DumpFile($config_file, $config_data);

    my $config = new_ok $CLASS, [
        config_filename         => 'test.gitpan',
        search_dirs             => [$tempdir],
    ];

    is $config->config_file, $config_file;
    is_deeply $config->config, { github => { token => "123abc" } };
};

subtest overlays => sub {
    my $tempdir = Path::Class::tempdir;
    my $config_file  = $tempdir->file("test.gitpan");

    my $config_data = {
        github          => { token => "123abc", foo => "bar" },
        overlays        => { test => { github => { token => "deadbeef" } } }
    };
    DumpFile($config_file, $config_data);

    my $config = new_ok $CLASS, [
        config_filename         => 'test.gitpan',
        search_dirs             => [$tempdir],
    ];

    is $config->config_file, $config_file;
    is_deeply $config->config, { github => { token => "deadbeef", foo => "bar" } };
};

done_testing;
