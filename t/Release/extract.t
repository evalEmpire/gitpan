#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;

use Gitpan::Test;
use Gitpan::Release;


subtest "basic extract" => sub {
    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1'
    ];

    throws_ok {
        $pony->extract;
    } qr{\Q@{[$pony->archive_file]} does not exist};

    $pony->get;
    my $path = $pony->extract;
    is $path, $pony->extract_dir;
    ok -d $path;
    ok -e $path->child("Makefile.PL");
};


subtest "empty archive" => sub {
    my $empty = new_ok "Gitpan::Release", [
        distname        => 'Bundle-Slash',
        version         => '2.11'
    ];

    $empty->get;

    throws_ok {
        $empty->extract;
    } qr{^Archive is empty};

    ok !$empty->extract_dir;
};


subtest "bad links" => sub {
    my $bad_links = new_ok "Gitpan::Release", [
        distname        => 'SMTP-Server',
        version         => '1.1'
    ];

    $bad_links->get;
    $bad_links->extract;
    ok $bad_links->extract_dir;

    my $tmp = Path::Tiny->tempdir;
    $bad_links->move($tmp);

    ok -l $tmp->child("Server/.#Spam.pm");
};


subtest "Too big for Github" => sub {
    my $too_big = new_ok "Gitpan::Release", [
        distname        => 'Lingua-JA-WordNet',
        version         => '0.21'
    ];

    $too_big->get( check_size => 0 );
    $too_big->extract;

    my $small_file = $too_big->extract_dir->child("share/LICENSE.txt");
    cmp_ok -s $small_file, ">", 1800, "small files preserved";

    my $big_file = $too_big->extract_dir->child("share/wnjpn-1.1_and_synonyms-1.0.db");

    my $big_file_size_in_megs = 101;
    my $too_big_url = "http://backpan.cpan.org/authors/id/P/PA/PAWAPAWA/Lingua-JA-WordNet-0.21.tar.gz";

    is $big_file->slurp_utf8, <<"END", "big files truncated";
Sorry, this file has been truncated by Gitpan.
It was $big_file_size_in_megs megs which exceeds Github's limit of 100 megs per file.
You can get the file from the original archive at $too_big_url
END

};

done_testing;
