#!/usr/bin/env perl

use strict;
use warnings;

use perl5i::2;
use Test::More;

{
    package Some::Class;
    use Gitpan::OO;
    with 'Gitpan::Role::HasUA';
}

note "shared ua"; {
    my $obj1 = Some::Class->new;
    isa_ok $obj1->ua, "LWP::UserAgent";

    my $obj2 = Some::Class->new;
    isa_ok $obj2->ua, "LWP::UserAgent";

    is $obj1->ua->mo->id, $obj2->ua->mo->id, "objects share ua objects";
}

done_testing;
