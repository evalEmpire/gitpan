package Git::CPAN::Patch::Import;

use strict;
use warnings;

use 5.010;

use File::chmod;   # use File::chmod *before* autodie to avoid a cage-match
use autodie;
use Archive::Extract; $Archive::Extract::PREFER_BIN = 1;
use File::Find;
use File::Basename;
use File::Temp;
use File::Path;
use File::chdir;
use version;
use Git;
use CLASS;
use Path::Class;

use CPANPLUS;
use BackPAN::Index;

our $BackPAN_URL = "http://backpan.perl.org/";

sub backpan_index {
    my $class = shift;
    my $opts = shift;

    state $backpan = do {
        say "Loading BackPAN index (this may take a while)";
        my %opts;
        $opts{backpan_index_url} = $opts->{backpan_index} if $opts->{backpan_index};
        BackPAN::Index->new(\%opts);
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


sub import_one_backpan_release {
    my $repo         = shift;
    my $release      = shift;
    my $opts         = shift;
    my $backpan_urls = ( ref $opts->{backpan}
                       ? $opts->{backpan}
                       : [ $opts->{backpan} || $BackPAN_URL ]
                       );

    my $git = $repo->git;

    my $last_commit  = $git->last_commit;
    my $last_version = $git->last_cpan_version;

    my $tmp_dir = File::Temp->newdir(
        $opts->{tempdir} ? (DIR     => $opts->{tempdir}) : ()
    );
    $tmp_dir = dir($tmp_dir);
    $tmp_dir->mkpath;

    my $archive_file = file($tmp_dir, $release->filename);

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
        local $ENV{GIT_INDEX_FILE} = file($tmp_dir, "temp_git_index");
        local $ENV{GIT_DIR} = dir( '.git' )->absolute;
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
    $git->run('update-ref', '-m' => "import $dist", 'refs/heads/cpan/master', $commit );

    if( $version ) {
        my $tag = $version;
        $tag =~ s{^\.}{0.};  # git does not like a leading . as a tag name
        $tag =~ s{\.$}{};    # nor a trailing one
        if( $git->run( "tag", "-l" => $tag ) ) {
            say "Tag $tag already exists, overwriting";
        }
        $git->run( "tag", "-f" => $tag, $commit );
        say "created tag '$tag' ($commit)";
    }
}


sub get_from_url {
    my($url, $file) = @_;

    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;

    my $req = HTTP::Request->new( GET => $url );
    my $res = $ua->request($req, $file."");

    return $res;
}


sub import_from_backpan {
    my ( $repo, $opts ) = @_;

    $repo->git;  # force the git repo to exist
    my $repo_dir = $repo->directory;
    local $CWD = $repo_dir;

    my $backpan = $CLASS->backpan_index($opts);
    my $dist = $backpan->dist($repo->distname)
      or die "Error: no distributions found. ",
             "Are you sure you spelled the module name correctly?\n";

    $repo->git->fixup_repository();

    my %existing_releases;
    %existing_releases = map { $_ => 1 } $repo->git->releases if $opts->{update};
    my $release_added = 0;
    for my $release ($dist->releases->search( undef, { order_by => "date" } )) {
        next if $existing_releases{$release->version};

        # skip .ppm files
        next if $release->filename =~ m{\.ppm\b};

        say "importing $release";
        import_one_backpan_release(
            $repo,
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

    if( !$repo->git->revision_exists("master") && $repo->git->revision_exists("cpan/master") ) {
        $repo->git->run('checkout', '-t', '-b', 'master', 'cpan/master');
    }
    else {
        $repo->git->run('checkout', 'master');
        $repo->git->run('merge', 'cpan/master');
    }

    return $repo_dir;
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
