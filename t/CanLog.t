#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

subtest "Setup class" => sub {
    package Foo;
    use Gitpan::OO;
    with
      "Gitpan::Role::CanLog",
      "Gitpan::Role::HasConfig";

    ::pass;
};


subtest "main_log" => sub {
    my $obj = Foo->new;
    $obj->main_log("something");
    $obj->main_log("and something\n");
    $obj->main_log("with ünicode");

    is $obj->config->gitpan_log_file->slurp_utf8, <<'END';
something
and something
with ünicode
END
    $obj->config->gitpan_log_file->remove;
};


subtest q[don't blow over $@] => sub {
    local $@ = 'foo';

    my $obj = Foo->new;
    $obj->main_log("something");
    is $@, 'foo';

    $obj->config->gitpan_log_file->remove;
};

subtest "main_log overloaded object" => sub {
    {
        package Bar;
        use Gitpan::OO;
        use overload
          q[""]         => sub { "some message" },
          fallback      => 1;
    }

    my $obj = Foo->new;
    $obj->main_log(Bar->new);

    is $obj->config->gitpan_log_file->slurp_utf8, <<'END';
some message
END
};


done_testing;
