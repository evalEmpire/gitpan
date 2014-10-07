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

note "not shared across forks"; {
    my $obj1 = Some::Class->new;
    isa_ok $obj1->backpan_index, "BackPAN::Index";

    my $child = child {
        my $self = shift;

        my $obj2 = Some::Class->new;
        my $obj3 = Some::Class->new;

        my @ok;
        push @ok, isnt $obj1->backpan_index->mo->id,
                       $obj2->backpan_index->mo->id, "forking gets a new index";
        push @ok, is   $obj2->backpan_index->mo->id,
                       $obj3->backpan_index->mo->id, "still shared in the same process";
        $self->say(scalar @ok);
    } pipe => 1;

    $child->wait;
    Test::More->builder->current_test( Test::More->builder->current_test + $child->read );
}

done_testing;
