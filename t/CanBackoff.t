#!/usr/bin/perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

note "Setup class for testing"; {
    package Foo;
    use Gitpan::OO;
    with "Gitpan::Role::CanBackoff";

    sub default_success_check {
        my $self = shift;
        my $response = shift;
        return $response ? 1 : 0;
    }
}

subtest "do_with_backoff()" => sub {
    my $obj = Foo->new;

    my $i = 0;
    is $obj->do_with_backoff(
           times => 5,
           code  => sub { ++$i },
           check => sub { $_[1] > 2 }
    ), 3;

    ok !$obj->do_with_backoff(
        times => 2,
        code  => sub { 42 },
        check => sub { 0 }
    );

    $i = 0;
    ok $obj->do_with_backoff( times => 2, code => sub { $i++ } );
};


subtest "do_with_backoff timing" => sub {
    my $obj = Foo->new;

    test_runtime(
        code    => sub { $obj->do_with_backoff( times => 4, code => sub { 0 } ) },
        time    => 3.5
    );
};

done_testing;
