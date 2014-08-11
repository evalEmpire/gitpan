#!/usr/bin/env perl

use lib 't/lib';
use perl5i::2;
use Gitpan::Test;

note "Setup testing class"; {
    package Foo;
    use Moo;
    with "Gitpan::Role::HasCPANAuthors";
}

note "Authors"; {
    my $obj = new_ok "Foo";
    my $authors = $obj->cpan_authors;
    isa_ok $authors, "Parse::CPAN::Authors";

    my $author = $authors->author("MSCHWERN");
    is $author->pauseid, "MSCHWERN";
    like $author->name,  qr{schwern}i;
    like $author->email, qr{schwern}i;
    like $author->email, qr{\@};
}

note "Same object"; {
    my $obj1 = new_ok "Foo";
    my $obj2 = new_ok "Foo";

    is $obj1->cpan_authors->mo->id, $obj2->cpan_authors->mo->id;
}

done_testing;
