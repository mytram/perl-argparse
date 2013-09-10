package ArgParse::ActionCount;

use strict;
use warnings;
use Carp;

sub nargs { 0 }

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    my $v = $namespace->get_attr($spec->{dest}) || 0;

    $namespace->set_attr( $spec->{dest}, $v + scalar(@$values) );
}

1;

