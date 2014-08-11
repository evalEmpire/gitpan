#!/usr/bin/env perl

use Gitpan::perl5i;
use Test::Most;
use Path::Tiny;
use YAML::XS qw(DumpFile);

my $CLASS = 'Gitpan::ConfigFile';
require_ok $CLASS;


# Test just the values in the Gitpan::Config object we care about,
# ignore defaults and the like.
func test_config($config, $want) {
    $want->each( func($method, $value) {
        is $config->$method, $value;
    });
}


subtest defaults => sub {
    my $config = new_ok $CLASS;

    ok !$config->is_test;
    is $config->config_filename, ".gitpan";
    is_deeply $config->search_dirs, [".", $ENV{HOME}];
    isa_ok $config->config, 'Gitpan::Config', "config should always return something";
    is_deeply $config->use_overlays, [];
} or BAIL_OUT("config didn't pass basic tests, this is bad");


subtest env_GITPAN_CONFIG_DIR => sub {
    my $tempdir = Path::Tiny->tempdir;
    my $config_file = $tempdir->child(".gitpan");
    local $ENV{GITPAN_CONFIG_DIR} = $tempdir;

    my $config_data = {
        github_access_token => "fromenv",
    };
    DumpFile($config_file, $config_data);

    my $config = new_ok $CLASS;
    test_config( $config->config, { github_access_token => "fromenv" } );
};


subtest read_config => sub {
    my $tempdir = Path::Tiny->tempdir;
    my $config_file  = $tempdir->child("test.gitpan");

    my $config_data = {
        github_access_token    => "123abc",
        overlays        => { foo => { github_access_token => "deadbeef" } }
    };
    DumpFile($config_file, $config_data);

    my $config = new_ok $CLASS, [
        config_filename         => 'test.gitpan',
        search_dirs             => [$tempdir],
    ];

    is $config->config_file, $config_file;
    test_config( $config->config, { github_access_token => "123abc" } );
};

subtest overlays => sub {
    my $tempdir = Path::Tiny->tempdir;
    my $config_file  = $tempdir->child("test.gitpan");

    my $config_data = {
        github_access_token     => "123abc",
        github_remote_host      => "example.com",
        overlays                => { test => { github_access_token => "deadbeef" } }
    };
    DumpFile($config_file, $config_data);

    my $config = new_ok $CLASS, [
        config_filename         => 'test.gitpan',
        search_dirs             => [$tempdir],
        is_test                 => 1,
    ];

    is $config->config_file, $config_file;
    test_config( $config->config, {
        github_access_token     => "deadbeef",
        github_remote_host      => "example.com"
    });
};

done_testing;
