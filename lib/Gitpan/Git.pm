use MooseX::Declare;

class Gitpan::Git extends Git::Repository {
    use perl5i::2;
    use Path::Class;
    use Gitpan::Types qw(Dir);
    use Git::Repository;

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

    # Git::Repository isn't a Moose class
    CLASS->meta->make_immutable( inline_constructor => 0 );
}

1;
