#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

note "Setup test classes"; {
    package Some::Class1;
    use Gitpan::OO;
    with 'Gitpan::Role::HasConfig';

    package Some::Class2;
    use Gitpan::OO;
    with 'Gitpan::Role::HasConfig';
}

note "Config is shared"; {
    my $obj1 = Some::Class1->new;
    isa_ok $obj1->config, "Gitpan::Config";

    my $obj2 = Some::Class2->new;
    isa_ok $obj2->config, "Gitpan::Config";

    is $obj1->config->mo->id, $obj2->config->mo->id;
}

note "As class method"; {
    isa_ok( Some::Class1->config, "Gitpan::Config" );
}

subtest "config changes with Gitpan::Config->default" => sub {
    my $obj = Some::Class1->new;

    my $config = $obj->config;

    my $new_config = Gitpan::Config->new;
    Gitpan::Config->set_default($new_config);

    is $obj->config->mo->id, $new_config->mo->id;
};

done_testing;
