package ArgParse::ActionStore;

use strict;
use warnings;
use Carp;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    croak sprintf('%s can only have one value', $spec->{dest})
        if @$values > 1;

    if ($spec->{type} == ArgParse::ArgumentParser::TYPE_BOOL) {
        # If there is default true or false
        my $default = $spec->{default} || [ 0 ];

        if (@$values) {
            $namespace->set_attr($spec->{dest}, !$default->[0]);
        } else {
            $namespace->set_attr($spec->{dest}, $default->[0]);
        }

        # make no_quiet available
        $namespace->set_attr( 'no_' . $spec->{dest}, !$namespace->get_attr($spec->{dest}) );

        return;
    }

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
