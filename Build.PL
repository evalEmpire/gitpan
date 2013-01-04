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
        "File::chdir"           => 0,
        "Getopt::Long::Descriptive"    => 0.085,
        "Git::Repository"       => 1.29,
        "Method::Signatures"    => 0,
        "Mouse"                 => 0,
        "Path::Class"           => 0,
        "perl5i::2"             => "v2.2.0",
        "Net::GitHub::V3"       => 0,
    }
);
$build->create_build_script;
