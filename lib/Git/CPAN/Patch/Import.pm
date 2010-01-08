package Git::CPAN::Patch::Import;

use strict;
use warnings;

use 5.010;

use autodie;

use Archive::Extract;
$Archive::Extract::PREFER_BIN = 1;

use File::chmod;
use File::Find;
use File::Basename;
use File::Spec::Functions;
use File::Temp qw(tempdir);
use File::Path;
use File::chdir;
use Cwd qw/ getcwd /;
use version;
use Git;
use CLASS;

use CPANPLUS;
use BackPAN::Index;

our $BackPAN_URL = "http://backpan.perl.org/";

sub backpan_index {
    state $backpan = do {
        say "Loading BackPAN index (this may take a while)";
        BackPAN::Index->new;
    };
    return $backpan;
}

sub cpanplus {
    state $cpanplus = CPANPLUS::Backend->new;
    return $cpanplus;
}

# Make sure we can read tarballs and change directories
sub _fix_permissions {
    my $dir = shift;

    chmod "u+rx", $dir;
    find(sub {
        -d $_ ? chmod "u+rx", $_ : chmod "u+r", $_;
    }, $dir);
}

sub init_repo {
    my $module = shift;
    my $opts   = shift;

    my $dirname = ".";
    if ( defined $opts->{mkdir} ) {
        ( $dirname = $opts->{mkdir} || $module ) =~ s/::/-/g;

        if( -d $dirname ) {
            die "$dirname already exists\n" unless $opts->{update};
        }
        else {
            say "creating directory $dirname";

            # mkpath() does not play nice with overloaded objects
            mkpath "$dirname";
        }
    }

    {
        local $CWD = $dirname;

        if ( -d '.git' ) {
            if ( !$opts->{force} and !$opts->{update} ) {
                die "Aborting: git repository already present.\n",
                    "use '-force' if it's really what you want to do\n";
            }
        }
        else {
            Git::command_noisy('init');
        }
    }

    return File::Spec->rel2abs($dirname);
}


sub releases_in_git {
    my $repo = Git->repository;
    return unless contains_git_revisions();
    my @releases = map  { m{\bgit-cpan-version:\s*(\S+)}x; $1 }
                   grep /^\s*git-cpan-version:/,
                     $repo->command(log => '--pretty=format:%b');
    return @releases;
}


sub rev_exists {
    my $rev = shift;
    my $repo = Git->repository;

    return eval {
        git_cmd_try {
            $repo->command(["rev-parse", $rev], {STDERR=>1});
        } "fail"
    };
}


sub contains_git_revisions {
    my $repo = Git->repository;

    return unless -d ".git";
    return rev_exists("HEAD");
}


sub import_one_backpan_release {
    my $release      = shift;
    my $opts         = shift;
    my $backpan_urls = ( ref $opts->{backpan}
                       ? $opts->{backpan}
                       : [ $opts->{backpan} || $BackPAN_URL ]
                       );

    my $repo = Git->repository;

    my( $last_commit, $last_version );

    # figure out if there is already an imported module
    if ( $last_commit = eval { $repo->command_oneline("rev-parse", "-q", "--verify", "cpan/master") } ) {
        $last_version = $repo->command_oneline("cpan-last-version");
    }

    my $tmp_dir = File::Temp->newdir(
        $opts->{tempdir} ? (DIR     => $opts->{tempdir}) : ()
    );

    my $archive_file = catfile($tmp_dir, $release->filename);
    mkpath dirname $archive_file;

    my $response;
    for my $backpan_url (@$backpan_urls) {
        my $release_url = $backpan_url . "/" . $release->prefix;

        say "Downloading $release_url";
        $response = get_from_url($release_url, $archive_file);
        last if $response->is_success;

        say "  failed @{[ $response->status_line ]}";
    }

    if( !$response->is_success ) {
        say "Fetch failed.  Skipping.";
        return;
    }

    if( !-e $archive_file ) {
        say "$archive_file is missing.  Skipping.";
        return;
    }

    say "extracting distribution";
    my $ae = Archive::Extract->new( archive => $archive_file );
    unless( $ae->extract( to => $tmp_dir ) ) {
        say "Couldn't extract $archive_file to $tmp_dir because ".$ae->error;
        say "Skipping";
        return;
    }

    my $dir = $ae->extract_path;
    if( !$dir ) {
        say "The archive is empty, skipping";
        return;
    }
    _fix_permissions($dir);

    my $tree = do {
        # don't overwrite the user's index
        local $ENV{GIT_INDEX_FILE} = catfile($tmp_dir, "temp_git_index");
        local $ENV{GIT_DIR} = catfile( getcwd(), '.git' );
        local $ENV{GIT_WORK_TREE} = $dir;

        local $CWD = $dir;

        my $write_tree_repo = Git->repository;

        $write_tree_repo->command_noisy( qw(add -v --force .) );
        $write_tree_repo->command_oneline( "write-tree" );
    };

    # Create a commit for the imported tree object and write it into
    # refs/remotes/cpan/master
    local %ENV = %ENV;
    $ENV{GIT_AUTHOR_DATE}  ||= $release->date;

    my $author = $CLASS->cpanplus->author_tree($release->cpanid);
    $ENV{GIT_AUTHOR_NAME}  ||= $author->author;
    $ENV{GIT_AUTHOR_EMAIL} ||= $author->email;

    my @parents = grep { $_ } $last_commit;

    # FIXME $repo->command_bidi_pipe is broken
    my ( $pid, $in, $out, $ctx ) = Git::command_bidi_pipe(
        "commit-tree", $tree,
        map { ( -p => $_ ) } @parents,
    );

    # commit message
    my $name    = $release->dist;
    my $version = $release->version || '';
    $out->print( join ' ', ( $last_version ? "import" : "initial import of" ), "$name $version from CPAN\n" );
    $out->print( <<"END" );

git-cpan-module:   $name
git-cpan-version:  $version
git-cpan-authorid: @{[ $author->cpanid ]}
git-cpan-file:     @{[ $release->prefix ]}

END

    # we need to send an EOF to git in order for it to actually finalize the commit
    # this kludge makes command_close_bidi_pipe not barf
    close $out;
    open $out, '<', \my $buf;

    chomp(my $commit = <$in>);

    Git::command_close_bidi_pipe($pid, $in, $out, $ctx);


    # finally, update the fake branch and create a tag for convenience
    my $dist = $release->dist;
    $repo->command_noisy('update-ref', '-m' => "import $dist", 'refs/heads/cpan/master', $commit );

    if( $version ) {
        my $tag = $version;
        $tag =~ s{^\.}{0.};  # git does not like a leading . as a tag name
        $tag =~ s{\.$}{};    # nor a trailing one
        if( $repo->command( "tag", "-l" => $tag ) ) {
            say "Tag $tag already exists, overwriting";
        }
        $repo->command_noisy( "tag", "-f" => $tag, $commit );
        say "created tag '$tag' ($commit)";
    }
}


sub get_from_url {
    my($url, $file) = @_;

    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;

    my $req = HTTP::Request->new( GET => $url );
    my $res = $ua->request($req, $file);

    return $res;
}


sub import_from_backpan {
    my ( $distname, $opts ) = @_;

    $distname =~ s/::/-/g;

    my $repo_dir = $opts->{init_repo} ? init_repo($distname, $opts) : $CWD;

    local $CWD = $repo_dir;

    my $backpan = $CLASS->backpan_index;
    my $dist = $backpan->dist($distname)
      or die "Error: no distributions found. ",
             "Are you sure you spelled the module name correctly?\n";

    fixup_repository();

    my %existing_releases;
    %existing_releases = map { $_ => 1 } releases_in_git() if $opts->{update};
    my $release_added = 0;
    for my $release ($dist->releases->search( undef, { order_by => "date" } )) {
        next if $existing_releases{$release->version};

        # skip .ppm files
        next if $release->filename =~ m{\.ppm\b};

        say "importing $release";
        import_one_backpan_release(
            $release,
            $opts,
        );
        $release_added++;
    }

    if( !$release_added ) {
        if( !keys %existing_releases ) {
            say "Empty repository for $dist.  Deleting.";

            # We can't delete it if we're inside it.
            $CWD = "..";
            rmtree $repo_dir;

            return;
        }
        else {
            say "No updates for $dist.";
            return;
        }
    }

    my $repo = Git->repository;
    if( !rev_exists("master") ) {
        $repo->command_noisy('checkout', '-t', '-b', 'master', 'cpan/master');
    }
    else {
        $repo->command_noisy('checkout', 'master');
        $repo->command_noisy('merge', 'cpan/master');
    }

    return $repo_dir;
}


sub fixup_repository {
    my $repo = Git->repository;

    return unless -d ".git";

    # We do our work in cpan/master, it might not exist if this
    # repo was cloned from gitpan.
    if( !rev_exists("cpan/master") and rev_exists("master") ) {
        $repo->command_noisy('branch', '-t', 'cpan/master', 'master');
    }
}


sub main {
    my $module = shift;
    my $opts   = shift;

    if ( delete $opts->{backpan} ) {
        return import_from_backpan( $module, $opts );
    }

    my $full_hist;

    my $repo = Git->repository;

    my ( $last_commit, $last_version );

    # figure out if there is already an imported module
    if ( $last_commit = eval { $repo->command_oneline("rev-parse", "-q", "--verify", "cpan/master") } ) {
        $module     ||= $repo->command_oneline("cpan-which");
        $last_version = $repo->command_oneline("cpan-last-version");
    }

    die("Usage: git cpan-import Foo::Bar\n") unless $module;

    # first we figure out a module object from the module argument
    # CPANPLUS handles dist names and URIs too

    # based on the version number it figured out for us we decide whether or not to
    # actually import.

    my $cpan = CPANPLUS::Backend->new;
    my $module_obj = $cpan->parse_module( module => $module ) or die("No such module $module");

    my $name    = $module_obj->name;
    my $version = $module_obj->version;
    my $dist    = $module_obj->package;
    my $dist_name = join("-", $module_obj->package_name, $module_obj->package_version);

    my $prettyname = $name . ( " ($module)" x ( $name ne $module ) );

    if ( $last_version and $opts->{checkversion} ) {
        # if last_version is defined this is an update
        my $imported = version->new($last_version);
        my $will_import = version->new($module_obj->version);

        die "$dist_name has already been imported\n" if $imported == $will_import;
    
        die "imported version $imported is more recent than $will_import, can't import\n"
          if $imported > $will_import;

        say "updating $prettyname from $imported to $will_import";
    
    } else {
        say "importing $prettyname";
    }



    # download the dist and extract into a temporary directory

    my $tmp_dir = tempdir( CLEANUP => 1 );

    say "downloading $dist";

    my $location = $module_obj->fetch( fetchdir => $tmp_dir )
      or die "couldn't retrieve distribution file for module $module";

    say "extracting distribution";

    my $dir = $module_obj->extract( extractdir => $tmp_dir )
      or die "couldn't extract distribution file $location";

    # create a tree object for the CPAN module
    # this imports the source code without touching the user's working directory or
    # index

    my $tree = do {
        # don't overwrite the user's index
        local $ENV{GIT_INDEX_FILE} = catfile($tmp_dir, "temp_git_index");
        local $ENV{GIT_DIR} = catfile( getcwd(), '.git' );
        local $ENV{GIT_WORK_TREE} = $dir;

        local $CWD = $dir;

        my $write_tree_repo = Git->repository;

        $write_tree_repo->command_noisy( qw(add -v --force .) );
        $write_tree_repo->command_oneline( "write-tree" );
    };





    # reate a commit for the imported tree object and write it into
    # refs/heads/cpan/master

    {
        local %ENV = %ENV;

        my $author_obj = $module_obj->author;

        # try to find a date for the version using the backpan index
        # secondly, if the CPANPLUS author object is a fake one (e.g. when importing a
        # URI), get the user object by using the ID from the backpan index
        unless ( $ENV{GIT_AUTHOR_DATE} ) {
            my $mtime = eval {
                return if $author_obj->isa("CPANPLUS::Module::Author::Fake");
                my $checksums = $module_obj->checksums;
                my $href = $module_obj->_parse_checksums_file( file => $checksums );
                return $href->{$dist}{mtime};
            };

            warn $@ if $@;

            if ( $mtime ) {
                $ENV{GIT_AUTHOR_DATE} = $mtime;
            } else {
                my %dists;

                if ( $opts->{backpan} ) {
                    # we need the backpan index for dates
                    my $backpan = $CLASS->backpan_index;

                    %dists = map { $_->filename => $_ } $backpan->releases($module_obj->package_name);
                }

                if ( my $bp_dist = $dists{$dist} ) {

                    $ENV{GIT_AUTHOR_DATE} = $bp_dist->date;

                    if ( $author_obj->isa("CPANPLUS::Module::Author::Fake") ) {
                        $author_obj = $cpan->author_tree($bp_dist->cpanid);
                    }
                } else {
                    say "Couldn't find upload date for $dist";

                    if ( $author_obj->isa("CPANPLUS::Module::Author::Fake") ) {
                        say "Couldn't find author for $dist";
                    }
                }
            }
        }

        # create the commit object
        $ENV{GIT_AUTHOR_NAME}  = $author_obj->author unless $ENV{GIT_AUTHOR_NAME};
        $ENV{GIT_AUTHOR_EMAIL} = $author_obj->email unless $ENV{GIT_AUTHOR_EMAIL};

        my @parents = ( grep { $_ } $last_commit, @{ $opts->{parent} || [] } );

        # FIXME $repo->command_bidi_pipe is broken
        my ( $pid, $in, $out, $ctx ) = Git::command_bidi_pipe(
            "commit-tree", $tree,
            map { ( -p => $_ ) } @parents,
        );

        # commit message
        $out->print( join ' ', ( $last_version ? "import" : "initial import of" ), "$name $version from CPAN\n" );
        $out->print( <<"END" );

git-cpan-module:   $name
git-cpan-version:  $version
git-cpan-authorid: @{[ $author_obj->cpanid ]}

END


        # we need to send an EOF to git in order for it to actually finalize the commit
        # this kludge makes command_close_bidi_pipe not barf
        close $out;
        open $out, '<', \my $buf;

        chomp(my $commit = <$in>);

        Git::command_close_bidi_pipe($pid, $in, $out, $ctx);


        # finally, update the fake remote branch and create a tag for convenience

        $repo->command_noisy('update-ref', '-m' => "import $dist", 'refs/remotes/cpan/master', $commit );

        $repo->command_noisy( tag => $version, $commit );

        say "created tag '$version' ($commit)";
    }
}

1;

__END__

=head1 NAME

Git::CPAN::Patch::Import - The meat of git-cpan-import

=head1 DESCRIPTION

This is the guts of Git::CPAN::Patch::Import moved here to make it callable
as a function so git-backpan-init goes faster.

=cut

1;
