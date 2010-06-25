use MooseX::Declare;

class Gitpan::Repo {
    use perl5i::2;
    use Path::Class;
    use Gitpan::Types qw(Distname AbsDir Dir);
    use Git;

    use overload
      q[""]     => method { return $self->distname },
      fallback  => 1;

    has distname        => 
      isa       => Distname,
      is        => 'ro',
      required  => 1
    ;

    has directory       =>
      isa       => AbsDir,
      is        => 'rw',
      required  => 1,
      lazy      => 1,
      default   => method {
          require Path::Class::Dir;
          return Path::Class::Dir->new($self->distname)->absolute;
      }
    ;

    has git     =>
      isa       => "Object",
      is        => 'rw',
      required  => 1,
      lazy      => 1,
      default   => method {
          $self->init_repo;
          return Git->repository( Directory => $self->directory );
      };

    has github  =>
      isa       => 'Gitpan::Github',
      is        => 'rw',
      required  => 1,
      lazy      => 1,
      default   => method {
          require Gitpan::Github;
          return Gitpan::Github->new(
              repo      => $self->distname,
          );
      };

    method init_repo {
        if( !-e $self->directory ) {
            $self->note("creating directory for $self");
            $self->directory->mkpath;
        }

        if( !-e $self->directory->subdir(".git") ) {
            $self->note("initializing repo for $self");
            local $CWD = $self->directory;
            Git::command_oneline("init");
        }

        return 1;
    }
}
