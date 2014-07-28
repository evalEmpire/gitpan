#!/usr/bin/perl

use strict;
use warnings;

use lib 'inc';

use MyBuilder;

my $build = MyBuilder->new(
    dist_name           => 'gitpan',
    dist_version        => '0.01',
    dist_author         => 'Michael G. Schwern <schwern@pobox.com>',
    dist_abstract       => "Put each CPAN distribution into its own Github repo",

    module_name         => 'Gitpan',

    configure_requires  => {
        "Module::Build"         => 0.42, # For test_requires
    },

    requires            => {
        perl                    => '5.18.1',

        "BackPAN::Index"        => 0.39,
        "Capture::Tiny"         => 0.08,        # exception bug
        'CPANPLUS'              => 0.9133,
        "File::chdir"           => 0,
        "File::chmod"           => 0.32,
        "Getopt::Long::Descriptive"    => 0.085,
        "Git::Repository"       => 1.300,
        "Git::Repository::Log"  => 1.312,
        "Method::Signatures"    => 0,
        "Moo"                   => '1.004002',
        "Mouse"                 => 0,
        "Path::Tiny"            => 0.054,       # symbolic chmod()
        "perl5i::2"             => "v2.13.0",
        "Net::GitHub::V3"       => '0.60',
        "Types::Standard"       => '0.044',
        "YAML::XS"              => 0,
    },

    test_requires       => {
        "Test::Most"            => 0,
        "Test::TypeConstraints" => 0.05,
    },
);
$build->create_build_script;
