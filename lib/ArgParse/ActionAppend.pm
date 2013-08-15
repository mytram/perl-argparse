package ArgParse::ActionAppend;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    my $v = $namespace->get_attr( $spec->{dest} ) || [];

    push @$v,
        map { $spec->{split} ? [ split($spec->{split}, $_) ] : $_ }
            @{$spec->{const} || []}, @$values;

    $namespace->set_attr( $spec->{dest}, $v );
}

1;

