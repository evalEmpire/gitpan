#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;
use Gitpan::Test;

use Gitpan::Dist;

subtest "error handling" => sub {
    my $dist = Gitpan::Dist->new(
        name        => "Acme-LookOfDisapproval"
    );
    $dist->delete_repo;

    my $break_at = $dist->release_from_version(0.003);

    ok !$dist->import_releases(
        after_import => method($release) {
            die "Testing error" if $release->version == $break_at->version;
        },
        push => 0,
    );

    like $dist->config->gitpan_log_file->slurp_utf8,
      qr{^Error importing @{[$break_at->short_path]}: Testing error }ms;
    like $dist->dist_log_file->slurp_utf8,
      qr{^Testing error }ms;
};


subtest "skipping releases" => sub {
    my $dist = Gitpan::Dist->new(
        name        => "Acme-LookOfDisapproval"
    );
    $dist->delete_repo;

    # Insert a release to skip into the config.  Be sure to clear out
    # the skip release cache.
    $dist->config->skip->{releases}->push('ETHER/Acme-LookOfDisapproval-0.003.tar.gz');
    $dist->config->_clear_skip_releases;

    $dist->import_releases( push => 0 );

    cmp_deeply $dist->git->releases, [
        'ETHER/Acme-LookOfDisapproval-0.001.tar.gz',
        'ETHER/Acme-LookOfDisapproval-0.002.tar.gz',
        'ETHER/Acme-LookOfDisapproval-0.004.tar.gz',
        'ETHER/Acme-LookOfDisapproval-0.005.tar.gz',
        'ETHER/Acme-LookOfDisapproval-0.006.tar.gz',
    ];
};

done_testing;

