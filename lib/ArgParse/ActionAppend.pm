package ArgParse::ActionAppend;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;

    $values ||= [];

    my $v = $namespace->get_attr($spec->{dest});
    unless ($v) {
        $v = [];
        push @$v, (defined($spec->{nargs}) ? $spec->{const} : @{$spec->{const}})
                              if defined $spec->{const};
        $namespace->set_attr( $spec->{dest}, $v );
    }

    push @$v, (defined($spec->{nargs}) ? $values : @$values );
}

1;

