use MooseX::Declare;

class Gitpan::Git
  extends Git::Repository
{
    use perl5i::2;
    use Path::Class;
    use Gitpan::Types;
    use Git::Repository;
    use MooseX::AlwaysCoerce;

    method clean {
        $self->remove_sample_hooks;
        $self->garbage_collect;
    }

    method hooks_dir {
        return dir($self->repo_path)->subdir("hooks");
    }

    method garbage_collect {
        $self->run("gc");
    }

    # These sample hook files take up a surprising amount of space
    # over thousands of repos.
    method remove_sample_hooks {
        my $hooks_dir = $self->hooks_dir;
        return unless -d $hooks_dir;

        for my $sample ([$hooks_dir->children]->grep(qr{\.sample$})) {
            $sample->remove or warn "Couldn't remove $sample";
        }

        return 1;
    }

    method remotes() {
        my @remotes = $self->run("remote", "-v");
        my %remotes;
        for my $remote (@remotes) {
            my($name, $url, $action) = $remote =~ m{^ (\S+) \s+ (.*?) \s+ \( (.*?) \) $}x;
            $remotes{$name}{$action} = $url;
        }

        return \%remotes;
    }

    method remote( Str $name, Str $action = "push" ) {
        return $self->remotes->{$name}{$action};
    }

    method change_remote( Str $name, Str $url ) {
        $self->run( remote => rm => $name );
        $self->run( remote => add => $name => $url );
    }

    method default_success_check($return?) {
        return $return ? 1 : 0;
    }

    method push( Str $remote = "origin", Str $branch = "master" ) {
        # sometimes github doesn't have the repo ready immediately after create_repo
        # returns, so if push fails try it again.
        my $ok = $self->do_with_backoff(
            times => 3,
            code  => sub {
                eval { $self->run(push => $remote => $branch) } || return
            },
        );
        return unless $ok;

        $self->run( push => $remote => "--tags" );

        return 1;
    }

    # At the bottom because it has to come before being made immutable
    # but after default_succes_check is declared
    with "Gitpan::CanBackoff";

    # Git::Repository isn't a Moose class
    CLASS->meta->make_immutable( inline_constructor => 0 );
}

1;
