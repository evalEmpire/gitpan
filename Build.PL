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

    requires            => {
        "BackPAN::Index"        => 0.39,
        "Capture::Tiny"         => 0.08, # exception bug
        'CPANPLUS'              => 0.9133,
        "File::chdir"           => 0,
        "File::chmod"           => 0.32,
        "Getopt::Long::Descriptive"    => 0.085,
        "Git::Repository"       => 1.300,
        "Method::Signatures"    => 0,
        "Mouse"                 => 0,
        "Path::Class"           => 0,
        "perl5i::2"             => "v2.2.0",
        "Net::GitHub::V3"       => 0,
        "YAML::XS"              => 0,
    },

    test_requires       => {
        "Test::Most"            => 0,
        "Test::TypeConstraints" => 0.05,
    },
);
$build->create_build_script;
