#!/usr/bin/env perl

use lib 't/lib';
use Gitpan::perl5i;

use Gitpan::Test;
use Gitpan::Release;

note "Required args"; {
    dies_ok { Gitpan::Release->new; };
    dies_ok {
        Gitpan::Release->new( distname => "Acme-Pony" );
    };
    dies_ok {
        Gitpan::Release->new( version => '1.1.1' );
    };
}


note "The basics"; {
    my $pony = Gitpan::Release->new(
        distname => 'Acme-Pony',
        version  => '1.1.1'
    );
    isa_ok $pony, "Gitpan::Release";

    is $pony->path,       "authors/id/D/DC/DCANTRELL/Acme-Pony-1.1.1.tar.gz";
    is $pony->short_path, "DCANTRELL/Acme-Pony-1.1.1.tar.gz";
}


note "short_path"; {
    my $german = new_ok 'Gitpan::Release', [
        distname        => 'Date-Spoken-German',
        version         => '0.04'
    ];

    is $german->path,       'authors/id/C/CH/CHRWIN/date-spoken-german/Date-Spoken-German-0.04.tar.gz';
    is $german->short_path, 'CHRWIN/date-spoken-german/Date-Spoken-German-0.04.tar.gz';
}


note "From a backpan release"; {
    my $pony = Gitpan::Release->new(
        distname        => 'Acme-Pony',
        version         => '1.1.1',
    );

    my $pony2 = Gitpan::Release->new(
        backpan_release => $pony->backpan_release
    );
    isa_ok $pony2, "Gitpan::Release";
    is $pony2->distname, "Acme-Pony";
    is $pony2->version,  "1.1.1";
}


note "Author info"; {
    my $pony = Gitpan::Release->new(
        distname => 'Acme-Pony',
        version  => '1.1.1'
    );
    isa_ok $pony, "Gitpan::Release";

    my $author = $pony->author;
    is   $author->cpanid,  "DCANTRELL";
    like $author->name,    qr{Cantrell}i;
}


subtest "gitpan_version" => sub {
    my $release = Gitpan::Release->new(
        distname        => 'Acme-eng2kor',
        version         => '0.0.1'
    );

    is $release->version,               '0.0.1';
    is $release->gitpan_version,        '0.0.1';

    $release = Gitpan::Release->new(
        distname        => 'Acme-eng2kor',
        version         => 'v0.0.2'
    );

    is $release->version,               'v0.0.2';
    is $release->gitpan_version,        '0.0.2';
};


note "get"; {
    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1'
    ];

    my $file = $pony->archive_file;
    like $file, qr{Acme-Pony};
    ok !-e $file;

    my $res = $pony->get;
    ok $res->is_success;
    ok -e $pony->archive_file;
}


subtest "get - bad size" => sub {
    my $release = new_ok "Gitpan::Release", [
        distname        => 'Lingua-JA-WordNet',
        version         => '0.21'
    ];

    throws_ok {
        $release->get();
    } qr/File not fully retrieved, got 139495, expected 60831235/;

    ok $release->get( check_size => 0 );
};


subtest "get from file urls" => sub {
    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1'
    ];

    my $res = $pony->get;
    ok $res->is_success;
    is $pony->archive_file, ($pony->url->path.'')->path->absolute;
};


subtest "get - file url does not exist" => sub {
    my $release = new_ok "Gitpan::Release", [
        distname => 'Acme-Pony',
        version  => '1.1.1',
        url      => 'file:///blah/blabity/blah'
    ];

    throws_ok {
        $release->get;
    } qr{^Could not find /blah/blabity/blah};
};

note "move"; {
    my $to = Path::Tiny->tempdir;

    my $pony = new_ok "Gitpan::Release", [
        distname => 'Acme-Warn-LOLCAT',
        version  => '0.01'
    ];

    $pony->get;
    $pony->move($to);
    ok !$pony->extract_dir, "Releases are not extracted after moving";

    ok ! -e $to->child(".git");

    $pony->extract;
    cmp_deeply [sort map { $_->basename } $to->children],
               [sort grep !/^.git$/, map { $_->basename } $pony->extract_dir->children];
}

done_testing;
