package ArgParse::ActionAppend;

use strict;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    if ($spec->{type} == ArgParse::ArgumentParser::TYPE_BOOL) {
        croak 'appending to type Bool not allowed';
    }

    my $v = $namespace->get_attr( $spec->{dest} );

    if ($spec->{type} == ArgParse::ArgumentParser::TYPE_PAIR) {
        $v = {} unless defined $v;

        for my $pair (@$values) {
            my ($key, $val) = %$pair;
            $v->{$key} = $val;
        }

    } else {
        $v = [] unless defined $v;
        push @$v, @$values;
    }

    $namespace->set_attr( $spec->{dest}, $v );
}

1;

