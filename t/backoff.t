#!/usr/bin/perl

use perl5i::2;
use Test::More;

use lib 'inc';

{
    package Foo;
    use Mouse;
    with "Gitpan::Role::CanBackoff";

    sub default_success_check {
        my $self = shift;
        my $response = shift;
        return $response ? 1 : 0;
    }
}

# do_with_backoff()
{
    my $obj = Foo->new;

    my $i = 0;
    is  $obj->do_with_backoff( times => 5, code => sub { ++$i }, check => sub { $_[1] > 2 } ), 3;

    ok  !$obj->do_with_backoff( times => 2, code => sub { 42 },   check => sub { 0 } );

    $i = 0;
    ok  $obj->do_with_backoff( times => 2, code => sub { $i++ } );
}


done_testing;
