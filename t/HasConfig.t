#!/usr/bin/env perl

use perl5i::2;
use Test::Most;

note "Setup test classes"; {
    package Some::Class1;
    use Mouse;
    with 'Gitpan::Role::HasConfig';

    package Some::Class2;
    use Mouse;
    with 'Gitpan::Role::HasConfig';
}

note "Config is shared"; {
    my $obj1 = Some::Class1->new;
    isa_ok $obj1->config, "Gitpan::Config";

    my $obj2 = Some::Class2->new;
    isa_ok $obj2->config, "Gitpan::Config";

    is $obj1->config->mo->id, $obj2->config->mo->id;
}

done_testing;
