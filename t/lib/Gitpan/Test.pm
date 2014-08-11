package Gitpan::Test;

use Gitpan::perl5i;

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
