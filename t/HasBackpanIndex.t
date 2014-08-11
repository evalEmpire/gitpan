#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

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
