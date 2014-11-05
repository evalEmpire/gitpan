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
    ArrayRef $names,
    Int  :$num_workers           = 2,
    Bool :$overwrite_repo           = 0,
) {
    my $fork_man = Parallel::ForkManager->new($num_workers);

    my $config = $self->config;

    # Parse the CPAN author's file in the parent so each child doesn't
    # have to redo the work.
    Gitpan::Dummy->new->build_cpan_authors;

    # Make sure the BackPAN index database is created else every
    # child will try to make it at the same time
    Gitpan::Dummy->new->backpan_index;

    $self->main_log("Starting import from distribution names at @{[gmtime->iso8601]}");

    for my $name (@$names) {
        if( $config->skip_dist($name) ) {
            $self->main_log( "Skipping $name due to config" );
            next;
        }

        my $pid = $fork_man->start and next;
        $self->import_from_distname(
            $name,
            overwrite_repo => $overwrite_repo
        );
        $fork_man->finish;
    }

    $fork_man->wait_all_children;

    $self->main_log("Import complete");

    return;
}

method import_from_backpan_dists(
    DBIx::Class::ResultSet $bp_dists,
    Int  :$num_workers  = 2,
    Bool :$overwrite_repo  = 0
) {
    my $fork_man = Parallel::ForkManager->new($num_workers);

    my $config = $self->config;

    # Parse the CPAN author's file in the parent so each child doesn't
    # have to redo the work.
    Gitpan::Dummy->new->build_cpan_authors;

    # Make sure the BackPAN index database is created else every
    # child will try to make it at the same time
    Gitpan::Dummy->new->backpan_index;

    $self->main_log("Starting import from BackPAN dists at @{[gmtime->iso8601]}");

    while( my $bp_dist = $bp_dists->next ) {
        my $distname = $bp_dist->name;

        if( $config->skip_dist($distname) ) {
            $self->main_log( "Skipping $distname due to config" );
            next;
        }

        my $dist = Gitpan::Dist->new(
            # Pass in the name to avoid sending an open sqlite connection
            # to the child.
            distname => $distname
        );

        my $pid = $fork_man->start and next;
        $self->import_dist($dist, overwrite_repo => $overwrite_repo);
        $fork_man->finish;
    }

    $self->main_log("Import complete");

    $fork_man->wait_all_children;
}


method import_dists(
    ArrayRef :$search_args,
    ArrayRef :$order_by_args,
    Int      :$num_workers      = 2
) {
    my $bp_dists = $self->backpan_index->dists;
    $bp_dists = $bp_dists->search_rs(@$search_args) if $search_args;
    $bp_dists->order_by(@$order_by_args)            if $order_by_args;

    $self->import_from_backpan_dists($bp_dists);

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
