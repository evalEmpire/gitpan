package Git::Repository::Log;

use strict;
use warnings;
use 5.006;

our $VERSION = '1.02';

# a few simple accessors
for my $attr (
    qw(
    commit tree
    author author_name author_email
    committer committer_name committer_email
    author_localtime author_tz author_gmtime
    committer_localtime committer_tz committer_gmtime
    raw_message message subject body
    extra
    )
    )
{
    no strict 'refs';
    *$attr = sub { return $_[0]{$attr} };
}
for my $attr (qw( parent )) {
    no strict 'refs';
    *$attr = sub { return @{ $_[0]{$attr} } };
}

sub new {
    my ( $class, @args ) = @_;
    my $self = bless { parent => [] }, $class;

    # pick up key/values from the list
    while ( my ( $key, $value ) = splice @args, 0, 2 ) {
        if ( $key eq 'parent' ) {
            push @{ $self->{$key} }, $value;
        }
        else {
            $self->{$key} = $value;
        }
    }

    # special case
    $self->{commit} = (split /\s/, $self->{commit} )[0];

    # compute other keys
    $self->{raw_message} = $self->{message};
    $self->{message} =~ s/^    //gm;
    @{$self}{qw( subject body )} = ( split( /\n/m, $self->{message}, 2 ), '' );
    $self->{body} =~ s/\A\s//gm;

    # author and committer details
    for my $who (qw( author committer )) {
        $self->{$who} =~ /(.*) <(.*)> (.*) (([-+])(..)(..))/;
        my @keys = ( "${who}_name", "${who}_email", "${who}_gmtime",
            "${who}_tz" );
        @{$self}{@keys} = ( $1, $2, $3, $4 );
        $self->{"${who}_localtime"} = $self->{"${who}_gmtime"}
            + ( $5 eq '-' ? -1 : 1 ) * ( $6 * 3600 + $7 * 60 );
    }

    return $self;
}

1;

__END__

=head1 NAME

Git::Repository::Log - Class representing git log data

=head1 SYNOPSIS

    # load the Log plugin
    use Git::Repository 'Log';

    # get the log for last commit
    my ($log) = Git::Repository->log( '-1' );

    # get the author's email
    print my $email = $log->author_email;

=head1 DESCRIPTION

L<Git::Repository::Log> is a class whose instances reprensent
log items from a B<git log> stream.

=head1 CONSTRUCTOR

This method shouldn't be used directly. L<Git::Repository::Log::Iterator>
should be the preferred way to create L<Git::Repository::Log> objects.

=head2 new( @args )

Create a new L<Git::Repository::Log> instance, using the list of key/values
passed as parameters. The supported keys are (from the output of
C<git log --pretty=raw>):

=over 4

=item commit

The commit id (ignore the extra information added by I<--decorate>).

=item tree

The tree id.

=item parent

The parent list, separated by spaces.

=item author

The author information.

=item committer

The committer information.

=item message

The log message (including the 4-space indent normally output by B<git log>).

=item extra

Any extra text that might be added by extra options passed to B<git log>.

=back

=head1 ACCESSORS

The following accessors methods are recognized. They all return scalars,
except for C<parent()>, which returns a list.

=head2 Commit information

=over 4

=item commit

=item tree

=item parent

=back

=head2 Author and committer information

=over 4

=item author

=item committer

The original author/committer line

=item author_name

=item committer_name

=item author_email

=item committer_email

=back

=head2 Date information

=over 4

=item author_gmtime

=item committer_gmtime

=item author_localtime

=item committer_localtime

=item author_tz

=item committer_tz

=back

=head2 Log information

=over 4

=item raw_message

The log message with the 4-space indent output by B<git log>.

=item message

The unindented version of the log message.

=item subject

=item body

=back

=head2 Extra information

=over 4

=item extra

=back

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

