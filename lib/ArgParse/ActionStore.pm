package ArgParse::ActionStore;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    unless (defined $spec->{nargs} ) {
        croak sprintf('%s can only have one value', $spec->{dest})
            if @$values > 1;

        croak sprintf('%s can only have one value: multiple const supplied', $spec->{dest})
            if defined($spec->{const}) && scalar(@{ $spec->{const} }) > 1;
    }

    if ( defined($spec->{nargs}) ) {
        if (defined $spec->{const}) {
            $namespace->set_attr($spec->{dest}, $spec->{const})
                if @$values;
        } else {
            $namespace->set_attr($spec->{dest}, $values);
        }
    } else {
        my $v;
        if (defined $spec->{const}) {
            $v = shift @{$spec->{const}} if @$values;
        } else {
            $v = shift @$values;
        }

        $namespace->set_attr($spec->{dest}, $v);
    }
}

1;
