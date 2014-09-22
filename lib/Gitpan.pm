package Gitpan;

use Gitpan::perl5i;
use Gitpan::OO;
use Gitpan::Types;

use Gitpan::Dist;
use Parallel::ForkManager;

with 'Gitpan::Role::HasBackpanIndex';


method import_from_distnames(
    ArrayRef $names,
    Int :$num_workers           = 2
) {
    my $fork_man = Parallel::ForkManager->new($num_workers);

    for my $name (@$names) {
#        my $pid = $fork_man->start and next;
        $self->import_from_distname($name);
#        $fork_man->finish;
    }

    $fork_man->wait_all_children;

    return;
}

method import_from_backpan_dists(
    DBIx::Class::ResultSet $bp_dists,
    Int      :$num_workers      = 2
) {
    my $fork_man = Parallel::ForkManager->new($num_workers);

    while( my $bp_dist = $bp_dists->next ) {
        my $dist = Gitpan::Dist->new(
            # Pass in the name to avoid sending an open sqlite connection
            # to the child.
            name => $bp_dist->name
        );

        my $pid = $fork_man->start and next;
        $self->import_dist($dist);
        $fork_man->finish;
    }

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


method import_from_distname( Str $name ) {
    $self->import_dist( Gitpan::Dist->new( name => $name ) );
}


method import_dist( Gitpan::Dist $dist ) {
    $dist->import_releases;
}
