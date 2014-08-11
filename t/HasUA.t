#!/usr/bin/env perl

use lib 't/lib';
use perl5i::2;
use Gitpan::Test;

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
