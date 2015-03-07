package Gitpan::Test;

use Gitpan::perl5i;
use Gitpan::ConfigFile;

use Import::Into;

use Test::Most ();

method import($class: ...) {
    my $caller = caller;

    warn "GITPAN_GITHUB_ACCESS_TOKEN is not set, tests which talk to Github will probably fail" unless $ENV{GITPAN_GITHUB_ACCESS_TOKEN};
    
    $ENV{GITPAN_CONFIG_DIR} //= "."->path->absolute;
    $ENV{GITPAN_TEST}       //= 1;

    Test::Most->import::into($caller);

    # Clean up and recreate the gitpan directory
    my $gitpan_dir = Gitpan::ConfigFile->new->config->gitpan_dir;
    croak "The gitpan directory used for testing ($gitpan_dir) is outside the test tree, refusing to delete it"
      if !"t"->path->subsumes($gitpan_dir);
    $gitpan_dir->remove_tree({safe => 0});
    $gitpan_dir->mkpath;

    (\&new_repo)->alias( $caller.'::new_repo' );
    (\&new_dist)->alias( $caller.'::new_dist' );
    (\&rand_distname)->alias( $caller.'::rand_distname' );
    (\&test_runtime)->alias( $caller.'::test_runtime' );

    return;
}


{
    package Gitpan::Dist::SelfDestruct;

    use Gitpan::perl5i;
    use Gitpan::OO;

    extends 'Gitpan::Dist';

    method DESTROY {
        eval {
            $self->delete_repo;
        };

        return;
    }
}


{
    package Gitpan::Repo::SelfDestruct;

    use Gitpan::perl5i;
    use Gitpan::OO;

    extends 'Gitpan::Repo';

    method DESTROY {
        eval {
            $self->delete_repo;
        };

        return;
    }
}


func rand_distname {
    my @names;

    my @letters = ("a".."z","A".."Z");
    for (0..rand(4)+1) {
        push @names, join "", map { $letters[rand @letters] } 1..rand(20);
    }

    return @names->join("-");
}


func new_dist_or_repo( $class!, %params ) {
    my $overwrite = delete $params{overwrite} // 1;

    # If we're using a random dist name, no need to check
    # if it already exists.
    if( !defined $params{distname} ) {
        $params{distname} = rand_distname;
        $overwrite = 0;
    }

    my $obj = $class->new( %params );
    $obj->delete_repo( wait => 1 ) if $overwrite;

    return $obj;
}


func new_repo(...) {
    return new_dist_or_repo( "Gitpan::Repo::SelfDestruct", @_ );
}


func new_dist(...) {
    return new_dist_or_repo( "Gitpan::Dist::SelfDestruct", @_ );
}


use Time::HiRes qw(gettimeofday);
func test_runtime(
    CodeRef :$code!,
    Num     :$time!,
    Num     :$delta     = 0.1
) {
    my $start_time = gettimeofday;
    $code->();
    my $end_time   = gettimeofday;

    my $time_spent = $end_time - $start_time;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Test::More::cmp_ok(
        abs($time_spent - $time), "<=", $delta,
        "$time_spent expected about $time"
    );
}


1;
