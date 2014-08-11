#!/usr/bin/env perl

# This distribution has proven a problem in the past.

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

my $DistName = 'Math-BigInt';

note "Import $DistName"; {
    my $dist = Gitpan::Dist->new(
        name        => $DistName
    );
    $dist->delete_repo;

    cmp_deeply $dist->versions_to_import, [qw(
        0.01
        1.35
        1.36
        1.37
        1.38
        1.39
        1.40
        1.41
        1.42
        1.43
        1.44
        1.45
        1.46
        1.47
        1.48
        1.49
        1.53
        1.54
        1.55
        1.56
        1.57
        1.58
        1.59
        1.60
        1.61
        1.62
        1.63
        1.64
        1.65
        1.66
        1.67
        1.68
        1.69
        1.70
        1.71
        1.72
        1.73
        1.74
        1.75
        1.76
        1.77
        1.78
        1.79
        1.80
        1.81
        1.82
        1.83
        1.84
        1.85
        1.86
        1.87
        1.88
        1.89
        1.90
        1.91
        1.92
        1.93
        1.94-TRIAL
        1.95
        1.96
        1.97
        1.98
        1.99
        1.99.1
        1.9902
        1.99_05
        1.991
        1.992
        1.993
        1.997
        1.9993
    )];

    $dist->import_new;
}

done_testing;
