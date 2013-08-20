package ArgParse::ActionStore;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    if ($spec->{type} == ArgParse::ArgumentParser::TYPE_BOOL) {
        my $v = $spec->{const}->[0];
        $namespace->set_attr($spec->{dest}, !$v);
        $namespace->set_attr($spec->{dest}, $v) if @$values;
        return;
    }

    croak sprintf('%s can only have one value', $spec->{dest})
        if @$values > 1;

    unless (@$values) {
        $namespace->set_attr($spec->{dest}, undef);
        return;
    }

    my $v = $values->[0];

    croak 'a value is required for option: ' . $spec->{dest}
        if defined $v && $v eq '';

    croak sprintf('%s can only have one value: multiple const supplied', $spec->{dest})
            if !defined $spec->{split}
                && defined($spec->{const})
                && scalar(@{ $spec->{const} }) > 1;

    $v = $spec->{const}->[0] if @$values && $spec->{const};

    $namespace->set_attr($spec->{dest}, $v);
}

1;
