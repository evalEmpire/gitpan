package Gitpan::Role::CanBackoff;

use perl5i::2;

use Moo::Role;
requires "default_success_check";

use Gitpan::Types;

use Method::Signatures;
use Time::HiRes qw(usleep);

method do_with_backoff(Int :$times=6, CodeRef :$code!, CodeRef :$check) {
    $check //= $self->can("default_success_check");

    for my $time (1..$times) {
        my $return = $code->();
        return $return if $check->($self, $return);

        # .5 1 2 4 8 ...
        usleep(2**($time-1)/2);
    }

    return;
}

1;
