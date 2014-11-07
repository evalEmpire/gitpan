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


method import_from_backpan_dists(
    DBIx::Class::ResultSet $bp_dists,
    Int  :$num_workers,
    Bool :$overwrite_repo
) {
    my $iter = sub {
        my $bp_dist = $bp_dists->next;
        return unless $bp_dist;
        return $bp_dist->name;
    };

    return $self->import_from_iterator(
        iterator        => $iter,
        num_workers     => $num_workers,
        overwrite_repo  => $overwrite_repo
    );    
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
