package Gitpan;

use Gitpan::perl5i;
use Gitpan::OO;
use Gitpan::Types;

use version; our $VERSION = qv("v2.3.0");

use Gitpan::Dist;
use Parallel::ForkManager;

with 'Gitpan::Role::HasBackpanIndex',
     'Gitpan::Role::HasConfig',
     'Gitpan::Role::CanLog';

{
    package Gitpan::Dummy;
    use Gitpan::OO;
    with 'Gitpan::Role::HasCPANAuthors',
         'Gitpan::Role::HasBackpanIndex';
}


method import_from_distnames(
    ArrayRef $distnames,
    Int  :$num_workers,
    Bool :$overwrite_repo
) {
    my $idx = 0;
    my $iter = sub {
        return $distnames->[$idx++];
    };

    return $self->import_from_iterator(
        iterator        => $iter,
        num_workers     => $num_workers,
        overwrite_repo  => $overwrite_repo
    );
}


method select_dists(
    DBIx::Class::ResultSet :$bp_dists = $self->backpan_index->dists,
    Maybe[Int]  :$limit,
    Maybe[Str]  :$name_like,
    Maybe[Str]  :$author,
    Bool        :$sort,
    Maybe[Int]  :$random,
    Maybe[Str]  :$since
) {
    $bp_dists = $bp_dists->search({ latest_date => \">= $since" })      if $since;

    $bp_dists = $bp_dists->search( undef, { order_by => \'random()',
                                            rows => $random } )         if $random;

    $bp_dists = $bp_dists->search( undef, { order_by => 'name' } )      if $sort;

    $bp_dists = $bp_dists->search({ "releases.cpanid" => $author },
                                  { join => "releases", distinct => 1 }) if $author;

    $bp_dists = $bp_dists->search({ name => { -like => $name_like } })  if $name_like;

    $bp_dists = $bp_dists->search( undef, { rows => $limit })           if $limit;

    return $bp_dists;
}


method import_from_backpan_dists(
    DBIx::Class::ResultSet :$bp_dists!,
    Bool        :$all_dists,
    Int         :$num_workers,
    Bool        :$overwrite_repo,
) {
    if( $all_dists ) {
        my $since = $self->read_latest_release_timestamp;
        $bp_dists = $self->select_dists(
            bp_dists        => $bp_dists,
            since           => $since
        );
        $self->main_log("Importing @{[$bp_dists->count]} dists changed since $since");
    }

    my $iter = sub {
        my $bp_dist = $bp_dists->next;
        return unless $bp_dist;
        return $bp_dist->name;
    };

    my $latest_release = $self->latest_release_date;

    my $ret = $self->import_from_iterator(
        iterator        => $iter,
        num_workers     => $num_workers,
        overwrite_repo  => $overwrite_repo
    );

    $self->write_latest_release_timestamp($latest_release) if $all_dists;

    return $ret;
}


method import_from_iterator(
    CodeRef :$iterator!,
    Int     :$num_workers       //= 2,
    Bool    :$overwrite_repo      = 0,
) {
    my $fork_man = Parallel::ForkManager->new($num_workers);

    my $config = $self->config;

    # Parse the CPAN author's file in the parent so each child doesn't
    # have to redo the work.
    Gitpan::Dummy->new->build_cpan_authors;

    # Make sure the BackPAN index database is created else every
    # child will try to make it at the same time
    Gitpan::Dummy->new->backpan_index;

    $self->main_log("Starting import at @{[gmtime->iso8601]}");

    while( my $distname = $iterator->() ) {
        if( $config->skip_dist($distname) ) {
            $self->main_log( "Skipping $distname due to config" );
            next;
        }

        my $pid = $fork_man->start and next;
        $self->import_from_distname(
            $distname,
            overwrite_repo => $overwrite_repo
        );
        $fork_man->finish;
    }

    $fork_man->wait_all_children;

    $self->main_log("Import complete at @{[gmtime->iso8601]}");

    return;
}


method import_from_distname(
    Str  $name,
    Bool :$overwrite_repo = 0
) {
    $self->import_dist(
        Gitpan::Dist->new( distname => $name ),
        overwrite_repo => $overwrite_repo
    );
}


method import_dist(
    Gitpan::Dist $dist,
    Bool :$overwrite_repo = 0,
) {
    $dist->delete_repo if $overwrite_repo;
    $dist->import_releases;
}


method latest_release_date() {
    return $self->backpan_index->releases->get_column("date")->max;
}


method read_latest_release_timestamp() {
    my $timestamp_file = $self->config->gitpan_latest_imported_release_timestamp;
    return 0 if !-e $timestamp_file;

    my($timestamp) = $timestamp_file->lines(
        {count => 1, chomp => 1}
    );
    return $timestamp;
}


method write_latest_release_timestamp( Str $date ) {
    my $timestamp_file = $self->config->gitpan_latest_imported_release_timestamp;
    return $timestamp_file->spew($date);
}
