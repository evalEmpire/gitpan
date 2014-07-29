package Gitpan::OO;

use perl5i::2;
use Scalar::Util;
require Moo;

sub import {
    my $class = shift;
    my $caller = caller;

    my $haz = func($name, %args) {
        $args{is} //= 'rw';

        if( defined $args{isa} and $args{isa}->isa("Type::Tiny") ) {
            $args{coerce} = $args{isa}->coercion;
        }
        elsif (exists($args{coerce}) and not $args{coerce}) {
            delete($args{coerce});
        }

        @_ = ($name, %args);
        goto "$caller"->can("has");
    };
    $haz->alias($caller.'::haz');

    unshift @_, "Moo";
    goto Moo->can("import");
}
