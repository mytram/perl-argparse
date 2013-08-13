package ArgParse::ActionCount;

use strict;
use warnings;
use Carp;

sub nargs { 0 }

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    $namespace->set_attr( $spec->{dest}, scalar(@$values) );
}

1;

