package MyBuilder;

use strict;
use warnings;

use base 'Module::Build';

use v5.12;
use Path::Tiny;

sub ACTION_build {
    my $self = shift;

    # Install distributions from src/ as needed.
    for my $archive (path( $self->base_dir, "src" )->children) {
        my($dist, $version) = $archive->basename =~ /^(.*)-([\d_.]+)\./;
        my $module = $dist;
        $module =~ s{-}{::}g;
        if( !eval "require $module" or
            version->parse($version) > version->parse($module->VERSION)
        ) {
            say "Installing $archive.";
            system "cpanm", $archive;
        }
    }

    return $self->SUPER::ACTION_build;
}

sub find_test_files {
    my $self = shift;

    my $tests = $self->SUPER::find_test_files;

    return [sort { lc $a cmp lc $b } @$tests];
}

1;
