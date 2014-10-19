#!/usr/bin/perl

use strict;
use warnings;

use lib 'inc';

use MyBuilder;

my $build = MyBuilder->new(
    dist_name           => 'Gitpan',
    module_name         => "Gitpan",
    dist_author         => 'Michael G. Schwern <schwern@pobox.com>',
    dist_abstract       => "Put each CPAN distribution into its own Github repo",

    configure_requires  => {
        "Module::Build"         => 0.42, # For test_requires
        "Path::Tiny"            => 0.054,
    },

    requires            => {
        perl                    => '5.18.1',

        "BackPAN::Index"        => 0.39,
        "Capture::Tiny"         => 0.08,        # exception bug
        "Email::Valid"          => '1.195',
        "File::chdir"           => 0,
        "File::chmod"           => 0.32,
        "File::Copy::Recursive" => 0.38,
        "Getopt::Long::Descriptive"    => 0.085,
        "Git::Raw"              => '0.42',
        "Git::Repository"       => 1.300,
        "Git::Repository::Log"  => 1.312,
        "Git::Repository::Status" => 0.03,      # ->ignored fix
        "Import::Into"          => '1.002000',
        "Method::Signatures"    => '20140224',
        "Moo"                   => '1.006000',  # DIE handler fix
        "Net::GitHub"           => '0.66',      # LWP::UserAgent option warning
        "Parallel::ForkManager" => '1.06',
        "Path::Tiny"            => 0.054,       # symbolic chmod()
        "perl5i::2"             => "v2.13.0",
        "Type::Library"         => 0.046,
        "Type::Utils"           => 0.046,
        "Types::Standard"       => 0.046,
        "YAML::XS"              => 0,
    },

    test_requires       => {
        "Test::Most"            => 0,
        "Test::TypeConstraints" => 0.05,
    },

    recursive_test_files => 1
);
$build->create_build_script;
