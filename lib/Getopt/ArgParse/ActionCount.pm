package Getopt::ArgParse::ActionCount;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    my $v = $namespace->get_attr($spec->{dest}) || 0;

    $namespace->set_attr( $spec->{dest}, $v + scalar(@$values) );

    return '';
}

1;

