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

# sub apply {
#    my $self = shift;
#    my ($parser, $namespace, $values, $option_string) = @_;
# }

1;
