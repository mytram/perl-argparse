package Getopt::ArgParse::ActionAppend;

use strict;
use warnings;
use Carp;

use Getopt::ArgParse::Parser;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    my $v = $namespace->get_attr( $spec->{dest} );

    if ($spec->{type} == Getopt::ArgParse::Parser::TYPE_PAIR) {
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

    return '';
}

1;

