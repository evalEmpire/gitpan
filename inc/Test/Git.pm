package Test::Git;

use strict;
use warnings;

use Exporter;
use Test::Builder;
use Git::Repository 1.15;
use File::Temp qw( tempdir );
use Cwd qw( cwd );
use Carp;

our $VERSION = '1.02';
our @ISA     = qw( Exporter );
our @EXPORT  = qw( has_git test_repository );

my $Test = Test::Builder->new();

sub has_git {
    my ( $version, @options ) = ( ( grep !ref, @_ )[0], grep ref, @_ );

    # check some git is present
    $Test->skip_all('Default git binary not found in PATH')
        if !Git::Repository::Command::_is_git('git');

    # check it's at least some minimum version
    my $git_version = Git::Repository->version(@options);
    $Test->skip_all(
        "Test script requires git >= $version (this is only $git_version)")
        if $version && Git::Repository->version_lt( $version, @options );
}

sub test_repository {
    my %args = @_;

    # setup some default values
    my $temp = $args{temp} || [ CLEANUP => 1 ];    # File::Temp options
    my $init = $args{init} || [];                  # git init options
    my $opts = $args{git}  || {};                  # Git::Repository options

    # git init requires at least Git 1.5.0
    my $git_version = Git::Repository->version($opts);
    croak "test_repository() requires git >= 1.5.0 (this is only $git_version)"
      if Git::Repository->version_lt( '1.5.0', $opts );

    # create a temporary directory to host our repository
    my $dir = tempdir(@$temp);

    # create the git repository there
    my $home = cwd;
    chdir $dir or croak "Can't chdir to $dir: $!";
    Git::Repository->run( init => @$init, $opts );

    # create the Git::Repository object
    my $gitdir = Git::Repository->run(qw( rev-parse --git-dir ));
    my $r = Git::Repository->new( git_dir => $gitdir, $opts );
    chdir $home or croak "Can't chdir to $home: $!";
    return $r;
}

1;

__END__

=head1 NAME

Test::Git - Helper functions for test scripts using Git

=head1 SYNOPSIS

    use Test::More;
    use Test::Git;
    
    # check there is a git binary available, or skip all
    has_git();
    
    # check there is a minimum version of git available, or skip all
    has_git( '1.6.5' );
    
    # check the git we want to test has a minimum version, or skip all
    has_git( '1.6.5', { git => '/path/to/alternative/git' } );
    
    # normal plan
    plan tests => 2;
    
    # create a new, empty repository in a temporary location
    # and return a Git::Repository object
    my $r = test_repository();
    
    # run some tests on the repository
    ...

=head1 DESCRIPTION

L<Test::Git> provides a number of helpful functions when running test
scripts that require the creation and management of a Git repository.


=head1 EXPORTED FUNCTIONS

=head2 has_git( $version, \%options )

Checks if there is a git binary available, or skips all tests.

If the optional L<$version> argument is provided, also checks if the
available git binary has a version greater or equal to C<$version>.

This function also accepts an option hash of the same kind as those
accepted by L<Git::Repository> and L<Git::Repository::Command>.

This function must be called before C<plan()>, as it performs a B<skip_all>
if requirements are not met.


=head2 test_repository( %options )

Creates a new empty git repository in a temporary location, and returns
a L<Git::Repository> object pointing to it.

This function takes options as a hash. Each key will influence a
different part of the creation process.

This call is the equivalent of the default call with no options:

    test_repository(
        temp => [ CLEANUP => 1 ],    # File::Temp::tempdir options
        init => [],                  # git init options
        git  => {},                  # Git::Repository options
    );

To create a I<bare> repository:

    test_repository( init => [ '--bare' ] );

To leave the repository in its location after the end of the test:

    test_repository( temp => [ CLEANUP => 0 ] );

Note that since C<test_repository()> uses C<git init> to create the test
repository, it requires at least Git version C<1.5.0>.

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010-2012 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

