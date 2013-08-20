package ArgParse::Action;

use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;
    my $real_class = ref $class || $class;

    my $self = { @_ };

    bless $self, $real_class;

    return $self;
}

1;
