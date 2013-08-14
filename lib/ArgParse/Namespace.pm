require 5.008001;

package ArgParse::Namespace;
{
    $ArgParse::Namespace::VERSION='0.01';
}

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

sub set_attr {
    my $self = shift;
    my ($dest, $values) = @_;

    $self->{'-values'}{$dest} = $values;
}

sub get_attr {
    my $self = shift;
    my ($dest) = @_;

    confess "Must provide $dest" unless $dest;

    return $self->{'-values'}{$dest} if  exists $self->{'-values'}{$dest};

    return undef;
}

our $AUTOLOAD;

sub AUTOLOAD {
    my $sub = $AUTOLOAD;

    (my $dest = $sub) =~ s/.*:://;

    my $self = shift;

    if ( exists $self->{'-values'}{$dest} ) {
        my $values = $self->{'-values'}{$dest};
        if (ref($values) eq 'ARRAY') {
            return wantarray ? @$values : $values;
        } elsif (ref($values) eq 'HASH') {
            return wantarray ? @$values : $values;
        } else {
            return $values;
        }
    } else {
        croak "$dest is an unknown option";
    }

    return '';
}

sub DESTROY { }

1;
