package Git::Repository::Plugin::Log;

use warnings;
use strict;
use 5.006;

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
sub _keywords { qw( log ) }

use Git::Repository::Log::Iterator;

our $VERSION = '1.02';

sub log {

    # skip the invocant when invoked as a class method
    shift if !ref $_[0];

    # get the iterator
    my $iter = Git::Repository::Log::Iterator->new(@_);

    # scalar context: return the iterator
    return $iter if !wantarray;

    # list context: return all Git::Repository::Log objects
    my @logs;
    while ( my $log = $iter->next ) {
        push @logs, $log;
    }
    return @logs;
}

1;

__END__

=head1 NAME

Git::Repository::Plugin::Log - Add a log() method to Git::Repository

=head1 SYNOPSIS

    # load the plugin
    use Git::Repository 'Log';

    my $r = Git::Repository->new();

    # get all log objects
    my @logs = $r->log(qw( --since=yesterday ));

    # get an iterator
    my $iter = $r->log(qw( --since=yesterday ));
    while ( my $log = $iter->next() ) {
        ...;
    }

=head1 DESCRIPTION

This module adds a new method to L<Git::Repository>.

=head1 METHOD

=head2 log( @args )

Run C<git log> with the given arguments.

In scalar context, returns a L<Git::Repository::Log::Iterator> object,
which can return L<Git::Repository::Log> objects on demand.

In list context, returns the full list L<Git::Repository::Log> objects.
Note that this can be very memory-intensive.

See L<Git::Repository::Log::Iterator>'s documentation for details about
how parameters are handled.

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Many thanks to Aristotle Pagaltzis who requested a C<log()> method in
the first place, and for very interesting conversations on the topic.

=head1 SEE ALSO

L<Git::Repository::Plugin>,
L<Git::Repository::Log::Iterator>,
L<Git::Repository::Log>.

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

