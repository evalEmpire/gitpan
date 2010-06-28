#!/usr/bin/perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    dist_name           => 'gitpan',
    dist_version        => '0.01',
    requires            => {
        "Capture::Tiny"         => 0.08, # exception bug
        "BackPAN::Index"        => 0.39,
        "File::chdir"           => 0,
        "perl5i::2"             => "v2.2.0",
        "MooseX::Types"         => 0,
        "Path::Class"           => 0,
        "MooseX::Declare"       => 0,
        "MooseX::Path::Class"   => '0.05',
        "Net::GitHub::V2"       => 0,
        "Git::Repository"       => 1.04,  # unreleased version in schwern/Git-Repository
    }
);
