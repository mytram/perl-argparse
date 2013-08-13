package ArgParse::ActionStore;

sub apply {
    my $self = shift;

    my ($spec, $namespace, $values) = @_;
    $values ||= [];

    if ( defined($spec->{nargs}) ) {
        $namespace->set_attr($spec->{dest}, $values);
    } else {
        if (defined $spec->{const}) {
            $namespace->set_attr($spec->{dest}, $spec->{const})
                if @$values;
        } else {
            my $v = shift @$values;
            $namespace->set_attr($spec->{dest}, $v);
        }
    }
}

1;
