use MooseX::Declare;

role Gitpan::Github::ResponseReader {
    use perl5i::2;

    method is_too_many_requests($response!) {
        return $self->get_response_errors($response)->first(qr/too many requests/);
    }

    method get_response_errors($response!) {
        my $error = $response->{error};
        return wantarray ? () : [] if !defined $error;

        my @errors = ref $error ? @$error : $error;
        return wantarray ? @errors : \@errors;
    }
}
