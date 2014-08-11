package Gitpan::perl5i;

use perl5i::2 ();
use Method::Signatures ();

use Import::Into;

sub import {
    my $caller = caller;
    perl5i::2->import::into($caller, "-skip" => ["Signatures"]);
    Method::Signatures->import::into($caller);
}

1;
