package Gitpan::Test;

use perl5i::2;
use Method::Signatures;

use Import::Into;

use Test::Most ();

method import($class: ...) {
    my $caller = caller;

    $ENV{GITPAN_CONFIG_DIR} //= "t";
    $ENV{GITPAN_TEST}       //= 1;

    Test::Most->import::into($caller);

    return;
}

1;
