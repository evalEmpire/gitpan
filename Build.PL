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
    }
);
