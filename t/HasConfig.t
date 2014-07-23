#!/usr/bin/env perl

use perl5i::2;
use Test::Most;

note "Setup test class"; {
    package Some::Class;
    use Mouse;
    with 'Gitpan::Role::HasConfig';
}

note "basics"; {
    my $obj = Some::Class->new;
    isa_ok $obj->config, "Gitpan::ConfigFile";
}

done_testing;
