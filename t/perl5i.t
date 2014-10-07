#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;

use Gitpan::Test;

note "Signatures"; {
    func with_signature( Str $msg = "default" ) {
        return $msg;
    }

    is with_signature, "default";
}

note "perl5i"; {
    is [1,2,3]->join(""), "123";
}

done_testing;
