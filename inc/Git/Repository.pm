package Git::Repository;

use warnings;
use strict;
use 5.006;

use Carp;
use File::Spec;
use Cwd qw( cwd realpath );
use Scalar::Util qw( looks_like_number );

use Git::Repository::Command;

our $VERSION = '1.29';

# a few simple accessors
for my $attr (qw( git_dir work_tree options )) {
    no strict 'refs';
    *$attr = sub { return ref $_[0] ? $_[0]{$attr} : () };
}

# backward compatible aliases
sub repo_path {
    carp "repo_path() is obsolete, please use git_dir() instead";
    goto &git_dir;
}
sub wc_path {
    carp "wc_path() is obsolete, please use work_tree() instead";
    goto &work_tree;
}

# helper function
sub _abs_path {
    my ( $path, $base ) = @_;
    my $abs_path = File::Spec->rel2abs( $path, $base );

    # normalize, but don't die on Win32 if the path doesn't exist
    eval { $abs_path = realpath($abs_path); };
    return $abs_path;
}

#
# support for loading plugins
#
sub import {
    my ( $class, @plugins ) = @_;

    for my $plugin (@plugins) {
        ( $plugin, my @names ) = @$plugin if ref $plugin;
        $plugin
            = substr( $plugin, 0, 1 ) eq '+'
            ? substr( $plugin, 1 )
            : "Git::Repository::Plugin::$plugin";
        eval "use $plugin; 1;" or croak $@;
        $plugin->install(@names);
    }
}

#
# constructor-related methods
#

sub new {
    my ( $class, @arg ) = @_;

    # create the object
    my $self = bless {}, $class;

    # take out the option hash
    my ( $options, %arg );
    {
        my @o;
        %arg = grep !( ref eq 'HASH' ? push @o, $_ : 0 ), @arg;
        croak "Too many option hashes given: @o" if @o > 1;
        $options = $self->{options} = shift @o || {};
    }

    # ignore 'input' option during object creation
    my $input = delete $options->{input};

    # setup default options
    # accept older for backward compatibility
    my ($git_dir) = grep {defined} delete @arg{qw( git_dir repository )};
    my ($work_tree) = grep {defined} delete @arg{qw( work_tree working_copy )};

    croak "Unknown parameters: @{[keys %arg]}" if keys %arg;

    # compute the various paths
    my $cwd = defined $options->{cwd} ? $options->{cwd} : cwd();

    # if work_tree or git_dir are relative, they are relative to cwd
    -d ( $git_dir = _abs_path( $git_dir, $cwd ) )
        or croak "directory not found: $git_dir"
        if defined $git_dir;
    -d ( $work_tree = _abs_path( $work_tree, $cwd ) )
        or croak "directory not found: $work_tree"
        if defined $work_tree;

    # if no cwd option given, assume we want to work in work_tree
    $cwd = defined $options->{cwd} ? $options->{cwd}
         : defined $work_tree      ? $work_tree
         :                           cwd();

    # we'll always have to compute it if not defined
    $self->{git_dir} = _abs_path(
        Git::Repository->run(
            qw( rev-parse --git-dir ),
            { %$options, cwd => $cwd }
        ),
        $cwd
    ) if !defined $git_dir;

    # there are 4 possible cases
    if ( !defined $work_tree ) {

        # 1) no path defined: trust git with the values
        # $self->{git_dir} already computed

        # 2) only git_dir was given: trust it
        $self->{git_dir} = $git_dir if defined $git_dir;

        # in a non-bare repository, the work tree is just above the gitdir
        if ( $self->run(qw( config --bool core.bare )) ne 'true' ) {
            $self->{work_tree}
                = _abs_path( File::Spec->updir, $self->{git_dir} );
        }
    }
    else {

        # 3) only work_tree defined:
        if ( !defined $git_dir ) {

            # $self->{git_dir} already computed

            # check work_tree is the top-level work tree, and not a subdir
            my $cdup = Git::Repository->run( qw( rev-parse --show-cdup ),
                { %$options, cwd => $cwd } );
            $self->{work_tree}
                = $cdup ? _abs_path( $cdup, $work_tree ) : $work_tree;
        }

        # 4) both path defined: trust the values
        else {
            $self->{git_dir}   = $git_dir;
            $self->{work_tree} = $work_tree;
        }
    }

    # sanity check
    my $gitdir
        = eval { _abs_path( $self->run(qw( rev-parse --git-dir )), $cwd ) }
        || '';
    croak "fatal: Not a git repository: $self->{git_dir}"
        if $self->{git_dir} ne $gitdir;

    # put back the ignored option
    $options->{input} = $input if defined $input;

    return $self;
}

sub create {
    my ( $class, @args ) = @_;
    my @output = $class->run(@args);
    my $gitdir;

    # create() is now deprecated
    carp "create() is deprecated, please use run() instead";

    # git init or clone until v1.7.1 (inclusive)
    if ( $output[0] =~ /^(?:Reinitialized existing|Initialized empty) Git repository in (.*)/ ) {
        $gitdir = $1;
    }

    # git clone after v1.7.1
    elsif ( $output[0] =~ /Cloning into (bare repository )?(.*)\.\.\./ ) {
        $gitdir = $1 ? $2 : File::Spec->catdir( $2, '.git' );
    }

    # some other command (no git repository created)
    else {return}

    return $class->new( git_dir => $gitdir, grep { ref eq 'HASH' } @args );
}

#
# command-related methods
#

# return a Git::Repository::Command object
sub command {
    shift @_ if !ref $_[0];    # remove class name if called as class method
    return Git::Repository::Command->new(@_);
}

# run a command, returns the output
# die with errput if any
sub run {
    my ( $self, @cmd ) = @_;

    # split the args to get the optional callbacks
    my @c;
    @cmd = grep { ref eq 'CODE' ? !push @c, $_ : 1 } @cmd;

    # run the command (pass the instance if called as an instance method)
    my $command
        = Git::Repository::Command->new( ref $self ? $self : (), @cmd );

    # return the output or die
    local $Carp::CarpLevel = 1;
    return $command->final_output(@c);
}

#
# version comparison methods
#

# NOTE: it doesn't make sense to try to cache the results of version():
# - yes, it will make faster benchmarks, but
# - the 'git' option allows to change the git binary anytime
# - version comparison is usually done once anyway
sub version {
    return (
        shift->run( '--version', grep { ref eq 'HASH' } @_ )
            =~ /git version (.*)/g )[0];
}

sub _version_eq {
    my ( $v1, $v2 ) = @_;
    my @v1 = split /\./, $v1;
    my @v2 = split /\./, $v2;

    return '' if @v1 != @v2;
    $v1[$_] ne $v2[$_] and return '' for 0 .. $#v1;
    return 1;
}

sub _version_gt {
    my ( $v1, $v2 ) = @_;
    my @v1 = split /\./, $v1;
    my @v2 = split /\./, $v2;

    # pick up any dev parts
    my @dev1 = splice @v1, -2 if substr( $v1[-1], 0, 1 ) eq 'g';
    my @dev2 = splice @v2, -2 if substr( $v2[-1], 0, 1 ) eq 'g';

    # skip to the first difference
    shift @v1, shift @v2 while @v1 && @v2 && $v1[0] eq $v2[0];

    # we're comparing dev versions with the same ancestor
    if ( !@v1 && !@v2 ) {
        @v1 = @dev1;
        @v2 = @dev2;
    }

    # prepare the bits to compare
    ( $v1, $v2 ) = ( $v1[0] || 0, $v2[0] || 0 );

    # rcX is less than any number
    return looks_like_number($v1)
             ? looks_like_number($v2) ? $v1 > $v2 : 1
             : looks_like_number($v2) ? ''        : $v1 gt $v2;
}

# every op is a combination of eq and gt
sub version_eq {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return _version_eq( $r->version(@o), $v );
}

sub version_ne {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return !_version_eq( $r->version(@o), $v );
}

sub version_gt {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return _version_gt( $r->version(@o), $v );
}

sub version_le {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    return !_version_gt( $r->version(@o), $v );
}

sub version_lt {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    my $V = $r->version(@o);
    return !_version_eq( $V, $v )
        && !_version_gt( $V, $v );
}

sub version_ge {
    my ( $r, $v, @o ) = ( shift, ( grep !ref, @_ )[0], grep ref, @_ );
    my $V = $r->version(@o);
    return _version_eq( $V, $v )
        || _version_gt( $V, $v );
}

1;

__END__

=head1 NAME

Git::Repository - Perl interface to Git repositories

=head1 SYNOPSIS

    use Git::Repository;

    # start from an existing repository
    $r = Git::Repository->new( git_dir => $gitdir );

    # start from an existing working copy
    $r = Git::Repository->new( work_tree => $dir );

    # start from a repository reachable from the current directory
    $r = Git::Repository->new();

    # or init our own repository first
    Git::Repository->run( init => $dir, ... );
    $r = Git::Repository->new( work_tree => $dir );

    # or clone from a URL first
    Git::Repository->run( clone => $url, $dir, ... );
    $r = Git::Repository->new( work_tree => $dir );

    # run commands
    # - get the full output (no errput)
    $output = $r->run(@cmd);

    # - get the full output as a list of lines (no errput)
    @output = $r->run(@cmd);

    # - process the output with callbacks
    $output = $r->run( @cmd, sub {...} );
    @output = $r->run( @cmd, sub {...} );

    # - obtain a Git::Repository::Command object
    #   (see Git::Repository::Command for details)
    $cmd = $r->command(@cmd);

    # obtain version information
    my $version = $r->version();

    # compare current git version
    if ( $r->version_gt('1.6.5') ) {
        ...;
    }

=head1 DESCRIPTION

L<Git::Repository> is a Perl interface to Git, for scripted interactions
with repositories. It's a low-level interface that allows calling any Git
command, whether I<porcelain> or I<plumbing>, including bidirectional
commands such as C<git commit-tree>.

A L<Git::Repository> object simply provides context to the git commands
being run. It is possible to call the  C<command()> and C<run()> methods
against the class itself, and the context (typically I<current working
directory>) will be obtained from the options and environment.

As a low-level interface, it provides no sugar for particular Git
commands. Specifically, it will not prepare environment variables that
individual Git commands may need or use.

However, the C<GIT_DIR> and C<GIT_WORK_TREE> environment variables are
special: if the command is run in the context of a L<Git::Repository>
object, they will be overridden by the object's C<git_dir> and
C<work_tree> attributes, respectively. It is however still possible to
override them if necessary, using the C<env> option.

L<Git::Repository> requires at least Git 1.5.0, and is expected to support
any later version.

See L<Git::Repository::Tutorial> for more code examples.

=head1 CONSTRUCTORS

There are two ways to create L<Git::Repository> objects:

=head2 new( %args, $options )

Create a new L<Git::Repository> object, based on an existing Git repository.

Parameters are:

=over 4

=item git_dir => $gitdir

The location of the git repository (F<.git> directory or equivalent).

For backward compatibility with versions 1.06 and before, C<repository>
is accepted in place of C<git_dir> (but the newer name takes precedence).

=item work_tree => $dir

The location of the git working copy (for a non-bare repository).

If C<work_tree> actually points to a subdirectory of the work tree,
L<Git::Repository> will automatically recompute the proper value.

For backward compatibility with versions 1.06 and before, C<working_copy>
is accepted in place of C<work_tree> (but the newer name takes precedence).

=back

If none of the parameter is given, L<Git::Repository> will find the
appropriate repository just like Git itself does. Otherwise, one of
the parameters is usually enough,
as L<Git::Repository> can work out where the other directory (if any) is.

C<new()> also accepts a reference to an option hash which will be used
as the default by L<Git::Repository::Command> when working with the
corresponding L<Git::Repository> instance.

So this:

    my $options = {
        git => '/path/to/some/other/git',
        env => {
            GIT_COMMITTER_EMAIL => 'book@cpan.org',
            GIT_COMMITTER_NAME  => 'Philippe Bruhat (BooK)',
        },
    };
    my $r = Git::Repository->new(
        work_tree => $dir,
        $options
    );

is equivalent to explicitly passing the option hash to each
C<run()> or C<command()>.

It probably makes no sense to set the C<input> option in C<new()>,
but L<Git::Repository> won't stop you.
Note that on some systems, some git commands may close standard input
on startup, which will cause a C<SIGPIPE>. L<Git::Repository::Command>
will raise an exception.

=head2 create( @cmd )

B<The C<create()> method is deprecated, and will go away in the future.>

Runs a repository initialization command (like C<init> or C<clone>) and
returns a L<Git::Repository> object pointing to it. C<@cmd> may contain
a hashref with options (see L<Git::Repository::Command>.

Do not use the I<-q> option on such commands. C<create()> needs to parse
their output to find the path to the repository.

C<create()> also accepts a reference to an option hash which will be
used to set up the returned L<Git::Repository> instance.

Now that C<create()> is deprecated, instead of:

    $r = Git::Repository->create( ... );

simply do it in two steps:

    Git::Repository->run( ... );
    $r = Git::Repository->new( ... );


=head1 METHODS

L<Git::Repository> supports the following methods:

=head2 command( @cmd )

Runs the git sub-command and options, and returns a L<Git::Repository::Command>
object pointing to the sub-process running the command.

As described in the L<Git::Repository::Command> documentation, C<@cmd>
may also contain a hashref containing options for the command.

=head2 run( @cmd )

Runs the command and returns the output as a string in scalar context,
or as a list of lines in list context. Also accepts a hashref of options.

Lines are automatically C<chomp>ed.

In addition to the options hashref supported by L<Git::Repository::Command>,
the parameter list can also contain code references, that will be applied
successively to each line of output. The line being processed is in C<$_>,
but the coderef must still return the result string (like C<map>).

If the git command printed anything on stderr, it will be printed as
warnings. If the git sub-process exited with status C<128> (fatal error),
or C<129> (usage message), C<run()> will C<die()>.

=head2 git_dir()

Returns the repository path.

=head2 repo_path()

For backward compatibility with versions 1.06 and before, C<repo_path()>
it provided as an alias to C<git_dir()>. It will be removed in a future
version.

=head2 work_tree()

Returns the working copy path.
Used as current working directory by L<Git::Repository::Command>.

=head2 wc_path()

For backward compatibility with versions 1.06 and before, C<wc_path()>
it provided as an alias to C<work_tree()>. It will be removed in a future
version.

=head2 options()

Return the option hash that was passed to C<< Git::Repository->new() >>.

=head2 version()

Return the version of git, as given by C<git --version>.

=head2 Version-comparison "operators"

Git evolves very fast, and new features are constantly added.
To facilitate the creation of programs that can properly handle the
wide variety of Git versions seen in the wild, a number of version
comparison "operators" are available.

They are named C<version_I<op>> where I<op> is the equivalent of the Perl
operators C<lt>, C<gt>, C<le>, C<ge>, C<eq>, C<ne>. They return a boolean
value, obtained by comparing the version of the git binary and the
version string passed as parameter.

The methods are:

=over 4

=item version_lt( $version )

=item version_gt( $version )

=item version_le( $version )

=item version_ge( $version )

=item version_eq( $version )

=item version_ne( $version )

=back

All those methods also accept an option hash, just like the others.

Note that there are a small number of cases where the version comparison
operators will I<not> compare versions correctly for I<very old> versions of
Git. Typical example is C<1.0.0a gt 1.0.0> which should return true, but
doesn't. This only matters in comparisons, only for version numbers prior to
C<1.4.0-rc1> (June 2006), and only when the compared versions are very close.

Other issues exist when comparing development version numbers with one
another. For example, C<1.7.1.1> is greater than both C<1.7.1.1.gc8c07>
and C<1.7.1.1.g5f35a>, and C<1.7.1> is less than both. Obviously,
C<1.7.1.1.gc8c07> will compare as greater than C<1.7.1.1.g5f35a>
(asciibetically), but in fact these two version numbers cannot be
compared, as they are two siblings children of the commit tagged
C<v1.7.1>).

If one were to compute the set of all possible version numbers (as returned
by C<git --version>) for all git versions that can be compiled from each
commit in the F<git.git> repository, the result would not be a totally ordered
set. Big deal.

Also, don't be too precise when requiring the minimum version of Git that
supported a given feature. The precise commit in git.git at which a given
feature was added doesn't mean as much as the release branch in which that
commit was merged.

=head1 PLUGIN SUPPORT

L<Git::Repository> intentionally has only few methods.
The idea is to provide a lightweight wrapper around git, to be used
to create interesting tools based on Git.

However, people will want to add extra functionality to L<Git::Repository>,
the obvious example being a C<log()> method that returns simple objects
with useful attributes.

Taking the hypothetical C<Git::Repository::Plugin::Hello> module which
source code is listed in the previous reference, the methods it provides
would be loaded and used as follows:

    use Git::Repository qw( Hello );

    my $r = Git::Repository->new();
    print $r->hello();
    print $r->hello_gitdir();

It's possible to load only a selection of methods from the plugin:

    use Git::Repository [ Hello => 'hello' ];

    my $r = Git::Repository->new();
    print $r->hello();

    # dies: Can't locate object method "hello_gitdir"
    print $r->hello_gitdir();

If your plugin lives in another namespace than C<Git::Repository::Plugin::>,
just prefix the fully qualified class name with a C<+>. For example:

    use Git::Repository qw( +MyGit::Hello );

See L<Git::Repository::Plugin> about how to create a new plugin.

=head1 OTHER PERL GIT WRAPPERS

(This section was written in June 2010. The other Git wrappers have
probably evolved since that time.)

A number of Perl git wrappers already exist. Why create a new one?

I have a lot of ideas of nice things to do with Git as a tool to
manipulate blobs, trees, and tags, that may or may not represent
revision history of a project. A lot of those commands can output
huge amounts of data, which I need to be able to process in chunks.
Some of these commands also expect to receive input.

What follows is a short list of "missing features" that I was looking
for when I looked at the existing Git wrappers on CPAN. They are the
"rational" reason for writing my own (the real reason being of course
"I thought it would be fun, and I enjoyed doing it").

Even though it works well for me and others, L<Git::Repository> has its
own shortcomings: it I<is> a I<low-level interface to Git commands>,
anything complex requires you to deal with input/output handles,
it provides no high-level interface to generate actual Git commands
or process the output of commands (but have a look at the plugins),
it doesn't fully work under Win32 yet, etc. One the following modules
may therefore be better suited for your needs, depending on what you're
trying to achieve.

=head2 Git.pm

Git.pm is not on CPAN. It is usually packaged with Git, and installed with
the system Perl libraries. Not being on CPAN makes it harder to install
in any Perl. It makes it harder for a CPAN library to depend on it.

It doesn't allow calling C<git init> or C<git clone>.

The C<command_bidi_pipe> function especially has problems:
L<http://kerneltrap.org/mailarchive/git/2008/10/24/3789584>


=head2 Git::Class

Depends on Moose, which seems an unnecessary dependency for a simple
wrapper around Git. The startup penalty could become significant for
command-line tools.

Although it supports C<git init> and C<git clone>
(and has methods to call any Git command), it is mostly aimed at
porcelain commands, and provides no way to control bidirectional commands
(such as C<git commit-tree>).


=head2 Git::Wrapper

Doesn't support streams or bidirectional commands.


=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 BUGS

Since version 1.17, L<Git::Repository> delegates the actual command
execution to L<System::Command>. Win32 support for that module is
currently very bad (the test suite hangs in a few places).
If you'd like better Win32 support for L<Git::Repository>, help me improve
L<System::Command>!

Please report any bugs or feature requests to C<bug-git-repository at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Git-Repository>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Repository


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-Repository>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-Repository>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-Repository>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-Repository>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to Todd Rinalo, who wanted to add more methods to
L<Git::Repository>, which made me look for a solution that would preserve
the minimalism of L<Git::Repository>. The C<::Plugin> interface is what
I came up with.

=head1 COPYRIGHT

Copyright 2010-2012 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

