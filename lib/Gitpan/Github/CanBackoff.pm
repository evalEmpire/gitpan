use MooseX::Declare;

role Gitpan::Github::CanBackoff {
    use perl5i::2;

    method default_success_check($response) {
        return $response ? 1 : 0;
    }

    method do_with_backoff(Int :$times=6, CodeRef :$code!, CodeRef :$check) {
        $check //= $self->can("default_success_check");

        for my $time (1..$times) {
            my $return = $code->();
            return $return if $check->($self, $return);

            sleep 2**$time;
        }

        return;
    }
}
