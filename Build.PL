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

        "Archive::Extract"      => '0.72',
        "Archive::Zip"          => '1.39',
        "BackPAN::Index"        => 0.39,
        "Email::Valid"          => '1.195',
        "Git::Raw"              => '0.49',
        "Git::Repository"       => 1.300,
        "Git::Repository::Log"  => 1.312,
        "Git::Repository::Status" => 0.03,      # ->ignored fix
        "Import::Into"          => '1.002000',
        "Method::Signatures"    => '20141021',
        "Moo"                   => '1.006000',  # DIE handler fix
        "Parallel::ForkManager" => '1.06',
        "Path::Tiny"            => 0.059,       # append_utf8 don't blow over $@
        "perl5i::2"             => "v2.13.0",
        "Pithub"                => '0.01027',   # caching, attr override, branch info
        "Type::Library"         => 0.046,
        "Type::Utils"           => 0.046,
        "Types::Standard"       => 0.046,
        "YAML::XS"              => 0,
    },

    test_requires       => {
        "Test::Most"            => 0,
        "Test::TypeConstraints" => 0.05,
    },

    # Avoid picking up tests in t/gitpan/repo/SO/Some-Dist/t/*
    test_files => "t/*.t t/*/*.t t/*/*/*.t",
);
$build->create_build_script;
