#!/usr/bin/env perl

use strict;
use warnings;

use perl5i::2;
use Test::More;

{
    package Some::Class;
    use Gitpan::OO;
    with 'Gitpan::Role::HasBackpanIndex';
}

note "shared index"; {
    my $obj1 = Some::Class->new;
    isa_ok $obj1->backpan_index, "BackPAN::Index";

    my $obj2 = Some::Class->new;
    isa_ok $obj2->backpan_index, "BackPAN::Index";

    is $obj1->backpan_index->mo->id, $obj2->backpan_index->mo->id, "objects share index objects";
}

done_testing;
