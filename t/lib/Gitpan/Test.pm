package Gitpan::Test;

use Gitpan::perl5i;
use Gitpan::ConfigFile;

use Import::Into;

use Test::Most ();

method import($class: ...) {
    my $caller = caller;

    $ENV{GITPAN_CONFIG_DIR} //= "t";
    $ENV{GITPAN_TEST}       //= 1;

    Test::Most->import::into($caller);

    # Clean up and recreate the gitpan directory
    my $gitpan_dir = Gitpan::ConfigFile->new->config->gitpan_dir;
    croak "The gitpan directory used for testing ($gitpan_dir) is outside the test tree, refusing to delete it"
      if !"t"->path->subsumes($gitpan_dir);
    $gitpan_dir->remove_tree({safe => 0});
    $gitpan_dir->mkpath;

    return;
}

1;
