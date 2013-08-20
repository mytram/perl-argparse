package ArgParse::ActionAppend;

use strict;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    my $v = $namespace->get_attr( $spec->{dest} ) || [];

    push @$v, @$values;

    $namespace->set_attr( $spec->{dest}, $v );
}

1;

