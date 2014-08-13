package Gitpan::Role::CanLog;

use Gitpan::perl5i;
use Moo::Role;
use Gitpan::Types;

use namespace::clean;

requires "config";

method log(Path::Tiny :$file, Str :$message) {
    $message .= "\n" unless $message =~ m{\n$};
    return $file->append_utf8($message);
}

method main_log($message) {
    return $self->log(
        file    => $self->config->gitpan_log_file,
        message => $message
    );
}
