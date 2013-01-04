package MyBuilder;

use strict;
use warnings;

use base 'Module::Build';

use autodie;
use File::Copy;
use File::Path;
use File::Spec;

sub ACTION_inc {
    my $self = shift;

    my $inc = File::Spec->catdir( $self->base_dir, "inc" );

    for my $dist ( glob("submodules/*") ) {
        chdir $dist;

        print "Installing $dist into $inc\n";
        system "cpanm", "--no-man-pages", "-l", $inc, ".";

        chdir $self->base_dir;
    }

    # Move the installs from the lib/perl5 location straight into inc.
    my $cpanm_install = File::Spec->catdir( $self->base_dir, "inc", "lib", "perl5" );
    for my $dir (glob "$cpanm_install/*") {
        system "mv", $dir, $inc;
    }

    rmtree File::Spec->catdir( $self->base_dir, "inc", "lib" );
    rmtree File::Spec->catdir( $self->base_dir, "inc", "man" );

    chdir $self->base_dir;

    return;
}

1;
