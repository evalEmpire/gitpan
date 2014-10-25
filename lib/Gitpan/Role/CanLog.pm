package Gitpan::Role::CanLog;

use Gitpan::perl5i;
use Moo::Role;
use Gitpan::Types;

use namespace::clean;

requires "config";

method _log(Path::Tiny :$file, Str|Object :$message) {
    $message .= "\n" unless $message =~ m{\n$};

    local $@;
    return $file->append_utf8($message);
}

method main_log($message) {
    return $self->_log(
        file    => $self->config->gitpan_log_file,
        message => $message
    );
}
