package Getopt::ArgParse::ActionStore;

use strict;
use warnings;
use Carp;

use Getopt::ArgParse::Parser;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    croak sprintf('%s can only have one value', $spec->{dest})
        if @$values > 1;

    if ($spec->{type} == Getopt::ArgParse::Parser::TYPE_BOOL) {
        # If there is default true or false
        my $default = $spec->{default} || [ 0 ];

        if (@$values) {
             # Negate the default if the arg appears on the command
             # line
            $namespace->set_attr($spec->{dest}, !$default->[0]);
        } else {
            $namespace->set_attr($spec->{dest}, $default->[0]);
        }

        # make no_arg available
        $namespace->set_attr( 'no_' . $spec->{dest}, !$namespace->get_attr($spec->{dest}) );

        return;
    }

    # Don't set it to undef. We may operate on a namespace with this
    # attr already set. In that case we don't want to override it.
    return unless @$values;

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
