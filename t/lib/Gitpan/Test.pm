package Gitpan::Test;

use v5.18;
use strict;
use warnings;

use Test::Most;
use parent 'Exporter::Tiny';

# Export all our public functions, including imported ones.
our @EXPORT = grep {
    my $glob = $Gitpan::Test::{$_};
    !/^_/ && *{$glob}{CODE}
} keys %Gitpan::Test::;

sub import {
    my $class  = $_[0];  # don't modify @_
    my $caller = caller;

    $ENV{GITPAN_CONFIG_DIR} //= "t";
    $ENV{GITPAN_TEST}       //= 1;

    $class->SUPER::import({ into => $caller });

    return;
}

1;
