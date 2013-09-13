package ArgParse::Namespace;

use Carp;
use strict;
use warnings;

sub new {
    my $class = shift;
    my $real_class = ref $class || $class;

    my $self = {};

    bless $self, $real_class;
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

sub set_block_attr {
    my $self = shift;
    my ($name, $id, $block) = @_; # A block is a hash

    croak "Must provide a non-empty block name" unless $name;
    croak "Must provide an identifier for block $name" unless $id;
    croak "Must provide a block" unless $block;

    croak "Block $name($id) already exists"
        if exists $self->{blocks}{$name}{$id};

    my $config = ArgParse::Namespace->new();

    while (my ($key, $value) = each %$block) {
        $config->set_attr($key => $value);
    }

    $self->{'-blocks'}{$name}{$id} = $config;
}

sub get_block_attr {
    my $self = shift;
    my ($name, $id) = @_;

    return unless $name;
    return {} unless $id;

    return $self->{'-blocks'}{$name}{$id}
        if exists $self->{'-blocks'}{$name}{$id};
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
            return wantarray ? %$values : $values;

        } else {
            return $values;
        }
    } elsif ( exists $self->{'-blocks'}{$dest} ) {
        return $self->get_block_attr($dest, shift);
    } else {
        croak "unknown option: $dest";
    }

    return '';
}

sub DESTROY { }

1;
