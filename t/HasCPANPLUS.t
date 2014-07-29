#!/usr/bin/env perl

use strict;
use warnings;

use perl5i::2;
use Test::More;

{
    package Some::Class;
    use Gitpan::OO;
    with 'Gitpan::Role::HasCPANPLUS';
}

note "shared cpanplus"; {
    my $obj1 = Some::Class->new;
    isa_ok $obj1->cpanplus, "CPANPLUS::Backend";

    my $obj2 = Some::Class->new;
    isa_ok $obj2->cpanplus, "CPANPLUS::Backend";

    is $obj1->cpanplus->mo->id, $obj2->cpanplus->mo->id, "objects share cpanplus objects";
}

done_testing;
