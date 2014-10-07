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
        }
    );

    like $dist->config->gitpan_log_file->slurp_utf8,
      qr{^Error importing @{[$break_at->short_path]}: Testing error }ms;
    like $dist->dist_log_file->slurp_utf8,
      qr{^Testing error }ms;
};

done_testing;

