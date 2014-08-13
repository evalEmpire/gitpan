package Gitpan::Role::CanDistLog;

use Gitpan::perl5i;
use Moo::Role;
use Gitpan::Types;

use namespace::clean;

with "Gitpan::Role::CanLog";

requires "config", "distname";

method dist_log_file {
    $self->config->gitpan_log_dir->child($self->distname_path);
}

method dist_log($message) {
    return $self->log(
        file    => $self->dist_log_file,
        message => $message
    );
}

method distname_path() {
    my $name = $self->distname;
    my @path = (
        uc $name->substr(0, 2) || "--",
        $name
    );
    use Path::Tiny;
    return path(@path);
}

method BUILD(...) {
    $self->dist_log_file->touchpath if !-e $self->dist_log_file;

    return;
}
