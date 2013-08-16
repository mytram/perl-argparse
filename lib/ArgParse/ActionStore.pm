package ArgParse::ActionStore;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    unless (@$values) {
        $namespace->set_attr($spec->{dest}, undef);
        return;
    }

    croak sprintf('%s can only have one value', $spec->{dest})
        if @$values > 1;

    my $v = $values->[0];

    croak sprintf('%s can only have one value: multiple const supplied', $spec->{dest})
            if !defined $spec->{split}
                && defined($spec->{const})
                && scalar(@{ $spec->{const} }) > 1;

    $v = $spec->{const}->[0] if $spec->{const};

    $namespace->set_attr($spec->{dest}, $v);
}

1;
