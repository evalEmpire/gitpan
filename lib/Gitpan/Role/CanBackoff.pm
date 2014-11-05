package Gitpan::Role::CanBackoff;

use Gitpan::perl5i;

use Moo::Role;
requires "default_success_check";

use Gitpan::Types;

use Time::HiRes qw(sleep);

method do_with_backoff(Int :$times=4, CodeRef :$code!, CodeRef :$check) {
    $check //= $self->can("default_success_check");

    for my $time (1..$times) {
        my $return = $code->();
        return $return if $self->$check($return);

        $self->backoff(tries => $time, max_tries => $times);
    }

    return;
}


method backoff(
    Int :$tries!,
    Int :$max_tries
) {
    # Infinity is not recognized as an integer
    $max_tries //= "Inf";

    # .5 1 2 4 8 ...
    sleep(2**($tries-1)/2) if $tries < $max_tries;

    return;
}

1;
