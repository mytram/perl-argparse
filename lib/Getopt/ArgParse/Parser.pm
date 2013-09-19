package Getopt::ArgParse::Parser;

use Moo;

use Carp;
use Getopt::Long qw(GetOptionsFromArray);
use Text::Wrap;

use Getopt::ArgParse::Namespace;

use constant {
    TYPE_UNDEF  => 0,
    TYPE_SCALAR => 1,
    TYPE_ARRAY  => 2,
    TYPE_COUNT  => 3,
    TYPE_PAIR	=> 4, # key=value pair
    TYPE_BOOL	=> 5,

    CONST_TRUE   => 1,
    CONST_FALSE  => 0,

    # Expose these?
	ScalarArg => 'scalar',
	ArrayArg  => 'Array',
    PairArg   => 'Pair',
    CountArg  => 'Count',
    BoolArg   => 'Bool',
};

# Allow customization
# default actions
my %Action2ClassMap = (
	'_store'       => 'Getopt::ArgParse::ActionStore',
    '_append'      => 'Getopt::ArgParse::ActionAppend',
    '_count'       => 'Getopt::ArgParse::ActionCount',
    # Not supported
    # '_help'        => 'ArgParse::ActionHelp',
    # '_version'     => 'ArgParse::ActionVersion',
);

my %Type2ConstMap = (
    ''        => TYPE_UNDEF(),
    'Scalar'  => TYPE_SCALAR(),
    'Array'   => TYPE_ARRAY(),
	'Count'   => TYPE_COUNT(),
    'Pair'    => TYPE_PAIR(),
    'Bool'    => TYPE_BOOL(),
);

# Program name. Default $0

has prog => ( is => 'rw', required => 1, default => sub { $0 }, );

# The description of the progam

has description => ( is => 'rw', required => 1, default => sub { '' }, );

# namespace() - Read/write

# Contains the parsed results.

has namespace => (
    is => 'rw',
    isa => sub {
        return undef unless $_[0]; # allow undef
        my $class = ref $_[0] || $_[0];
        croak 'argparse: ' .  "Must provide a Namespace" unless $class;
    },
);

# parent - Readonly

has parent => (
    is => 'ro',
       isa => sub {
           my $parent_class = ref $_[0] || $_[0];
        die 'Parent must be an ArgumentParser'
            unless $parent_class->isa(__PACKAGE__);
    },
    required => 0,
);

# parser_configs - Read/write

# The configurations that will be passed to Getopt::Long::Configure(
# $self->parser_configs ) when parse_args is invoked.

has parser_configs => ( is => 'rw', required => 1, default => sub { [] }, );

# internal properties
has _option_position => ( is => 'rw', required => 1, default => sub { 0 } );

sub BUILD {
    my $self = shift;

    $self->{-option_specs} = {};
    $self->{-position_specs} = {};

    $self->add_argument(
        '--help', '-h',
        type => 'Bool',
        help => 'show this help message and exit',
    );

    $self->add_argument(
        '--verbose', '-v',
        type => 'Bool',
        help => 'verbose output',
    );

    # merge
    if ($self->parent) {
        $self->add_arguments( @ { $self->parent->{-pristine_add_arguments} || [] } );
    }
}

# add_arguments([arg_spec], [arg_spec1], ...)
# Add multiple arguments.
# Interace method
sub add_arguments {
    my $self = shift;

    $self->add_argument(@$_) for @_;
}

sub add_argument {
    my $self = shift;

    return unless @_; # mostly harmless

    push @{ $self->{-pristine_add_arguments} }, [ @_ ];

    my ($name, $flags, $rest) = $self->_parse_for_name_and_flags([ @_ ]);

    croak 'argparse: ' .  "Incorrect arguments" if scalar(@$rest) % 2;

    my $args = { @$rest };

    croak 'argparse: ' .  "Must provide at least one non-empty argument name" unless $name;

    my @flags = @{ $flags || [] };

    ################
    # type
    ################
    my $type_name = delete $args->{type} || '';
    my $type = $Type2ConstMap{$type_name} if exists $Type2ConstMap{$type_name};

    croak 'argparse: ' .  "Unknown type: $type_name" unless defined $type;

    if ($type == TYPE_COUNT) {
        $args->{action} = '_count' unless defined $args->{action};
        $args->{default} = 0 unless defined $args->{default};
    } elsif ($type == TYPE_ARRAY || $type == TYPE_PAIR) {
        $args->{action} = '_append' unless defined $args->{action};
    } else {
        # pass
    }

    ################
    # action
    ################
    my $action_name = delete $args->{action} || '_store';

    my $action = $Action2ClassMap{$action_name}
        if exists $Action2ClassMap{$action_name};

    $action = $action_name unless $action;

    {
        local $SIG{__WARN__};
        local $SIG{__DIE__};

        eval "require $action";

        croak 'argparse: ' .  "Cannot find the module for action $action" if $@;
    };

    ################
    # split
    ################
    my $split = delete $args->{split};
    if (defined $split && !$split && $split =~ /^ +$/) {
        croak 'argparse: ' .  'cannot split by whitespaces';
    }

    if (defined $split && $type != TYPE_ARRAY && $type != TYPE_PAIR) {
        croak 'argparse: ' .  'Only allow split to be used with either Array or Pair type';
    }

    ################
    # default
    ################
    my $default;
    if (exists $args->{default}) {
        my $val = delete $args->{default};
        if (ref($val) eq 'ARRAY') {
            $default = $val;
        } elsif (ref($val) eq 'HASH') {
            croak 'argparse: ' .  'HASH default only for Pair type options'
                if $type != TYPE_PAIR;
            $default = $val;
        } else {
            $default = [ $val ];
        }

        if ($type != TYPE_PAIR) {
            if ($type != TYPE_ARRAY && scalar(@$default) > 1) {
                croak 'argparse: ' . 'multiple default values for scalar type: $name';
            }
        }
    }

    ################
    # choices
    ################
    my $choices = delete $args->{choices} || undef;
    if (   $choices
        && ref($choices) ne 'CODE'
        && ref($choices) ne 'ARRAY' )
    {
        croak 'argparse: ' .  "Must provide choices in an arrayref or a coderef";
    }

    my $choices_i = delete $args->{choices_i} || undef;

    if ($choices && $choices_i) {
        croak 'argparse: ' . 'Not allow to specify choices and choices_i';
    }

    if (   $choices_i
        && ref($choices_i) ne 'ARRAY' )
    {
        croak 'argparse: ' .  "Must provide choices_i in an arrayref";
    }

    ################
    # required
    ################
    my $required = delete $args->{required} || '';

    ################
    # help
    ################
    my $help = delete $args->{help} || '';

    ################
    # groups - grouping options
    ################
    my $groups = delete $args->{groups} || [ '' ]; # anonymous group

    if (ref $groups ne 'ARRAY') {
        $groups = [ $groups ];
    }

    ################
    # metavar
    ################
    my $metavar = delete $args->{metavar} || uc($name);

    $metavar = ''
        if $type == TYPE_BOOL
            || $action_name eq '_count';

    ################
    # dest
    ################
    my $dest = delete $args->{dest} || $name;
    $dest =~ s/-/_/g; # option-name becomes option_name

    if (@flags) {
        while (my ($d, $s) = each %{$self->{-option_specs}}) {
            if ($dest ne $d) {
                for my $f (@flags) {
                   croak 'argparse: ' .  "$f already used for a different option ($d)"
                        if grep { $f eq $_ } @{$s->{flags}};
                }
            }
        }

        if (exists $self->{-position_specs}{$dest}) {
            croak "argparse: dest=$dest is used by a positional argument";
        }
    } else {
        if (exists $self->{-option_specs}{$dest}) {
            croak "argparse: dest=$dest is used by an optional argument";
        }
    }

    ################
    # nargs - positional only
    ################

    my $nargs = delete $args->{nargs};

    if (defined $nargs ) {
        croak 'argparse: ' . 'nargs only allowed for positional options' if @flags;
    }

    # never modify existing ones so that the parent's structure will
    # not be modified
    my $spec = {
        name      => $name,
        flags     => \@flags,
        action    => $action,
        nargs     => $nargs,
        split     => $split,
        required  => $required || '',
        type      => $type,
        default   => $default,
        choices   => $choices,
        choices_i => $choices_i,
        dest      => $dest,
        metavar   => $metavar,
        help      => $help,
        groups    => $groups,
        position  => $self->{-option_position}++, # sort order
    };

    my $specs;
    if (@flags) {
        $specs = $self->{-option_specs};
    } else {
        $specs = $self->{-position_specs}{$spec->{dest}} = $spec;
    }

    # reset
    if (delete $args->{reset}) {
        $self->namespace->set_attr($spec->{type}, undef) if $self->namespace;
        delete $specs->{$spec->{dest}};
    }

    croak sprintf(
        'argparse: unknown spec parameters: %s',
        join(',', keys %$args)
    ) if keys %$args;

    # type check
    if (exists $specs->{$spec->{dest}}{type}
            && $specs->{$spec->{dest}}{type} != $spec->{type}) {
        croak sprintf(
            'argparse: not allow to override %s with different type',
            $spec->{dest},
        );
    }

    # override
    $specs->{$spec->{dest}} = $spec;

    # specs changed, need to force to resort specs by groups
    delete $self->{-groups} if $self->{-groups};

    return $self;
}

sub add_group_description {
    my $self = shift;
    my ($group, $desc) = @_;

    return unless defined($group) && $desc;

    $self->{-group_description}{$group} = $desc;
}

sub _parse_for_name_and_flags {
    my $self = shift;
    my $args = shift;

    my ($name, @flags);
  FLAG:
    while (my $flag = shift @$args) {
        if (substr($flag, 0, 1) eq '-') {
            push @flags, $flag;
        } else {
            unshift @$args, $flag;
            last FLAG;
        }
    }

    # It's a positional argument spec if there are no flags
    $name = @flags ? $flags[0] : shift(@$args);
    $name =~ s/^-+//g;

    return ( $name, \@flags, $args );
}

# parse_args([@_])
#
# Parse @ARGV if called without passing arguments. It returns an
# instance of ArgParse::Namespace upon success
#
# Interface

sub parse_args {
    my $self = shift;

    my @saved_argv = @ARGV;

    my @argv = scalar(@_) ? @_ : @ARGV;

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-option_specs}};

    my @position_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-position_specs}};

    $self->namespace(Getopt::ArgParse::Namespace->new) unless $self->namespace;

    unless (@argv) {
        for (@option_specs, @position_specs) {
            # only show usage if no args will be populated due to an
            # empty command line
            if ( $_->{required}
                     && !defined($_->{default})
                     && !defined($self->namespace->get_attr($_->{dest}))
            )
            {
                $self->usage();
                exit(0);
            }
            # otherwise continue to initialise options
        }
    }

    $self->{-argv} = \@argv;

    $self->_parse_optional_args(\@option_specs) if @option_specs;

    $self->_parse_positional_args(\@position_specs) if @position_specs;

    if ($self->namespace->get_attr('help')) {
        my $usage = $self->usage();
        exit(0);
    }

    return $self->namespace;
}

sub _parse_optional_args {
    my $self = shift;
    my $specs = shift;
    my $options   = {};
    my $dest2spec = {};

    for my $spec ( @$specs ) {
        my @values;
        $dest2spec->{$spec->{dest}} = $self->_get_option_spec($spec);
        $options->{ $dest2spec->{$spec->{dest}} } = \@values;
    }

    Getopt::Long::Configure( @{ $self->parser_configs } );

    {
        my $warn;
        local $SIG{__WARN__} = sub { $warn = shift };

        my $result = GetOptionsFromArray( $self->{-argv}, %$options );

        if ($warn || !$result) {
            croak 'argparse: ' .  "Getoptions error: $warn";
        }
    }

    Getopt::Long::Configure('default');

    my $error = $self->_post_parse_processing( $specs, $options, $dest2spec );

    croak 'argparse: ' .  $error if $error;

    $self->_apply_action($specs, $options, $dest2spec);
}

sub _parse_positional_args {
    my $self = shift;
    my $specs = shift;

    my $options   = {};
    my $dest2spec = {};

    for my $spec (@$specs) {
        $dest2spec->{$spec->{dest}} = $spec->{dest};
        my @values = ();
        # Always assigne values to an option
        $options->{$spec->{dest}} = \@values;
    }

  POSITION_SPEC:
    for my $spec (@$specs) {
        my $values = $options->{$spec->{dest}};

        if ($spec->{type} == TYPE_BOOL) {
            croak 'argparse: ' .  'Bool not allowed for positional arguments';
        }

        my $number = 1;
        my $nargs = defined $spec->{nargs} ? $spec->{nargs} : 1;
        if (defined $spec->{nargs}) {
            if ($nargs eq '?') {
                $number = 1;
            } elsif ($nargs eq '+') {
                croak 'argparse: ' . "too few arguments: narg='+'" unless @{$self->{-argv}};
                $number = scalar @{$self->{-argv}};
            } elsif ($nargs eq '*') { # remainder
                $number = scalar @{$self->{-argv}};
            } elsif ($nargs !~ /^\d+$/) {
                croak 'argparse: ' .  'invalid nargs:' . $nargs;
            } else {
                $number = $nargs;
            }
        }

        push @$values, splice(@{$self->{-argv}}, 0, $number) if @{$self->{-argv}};

        # If no values, let it pass for required checking
        # If there are values, make sure there is the right number of
        # values
        if (scalar(@$values) && scalar(@$values) != $number) {
            croak(
                sprintf(
                    'argparse: not enough arguments for %s: expected:%d,actual:%d',
                    $spec->{dest}, $number, scalar(@$values),
                )
            );
        }
    }

    my $error = $self->_post_parse_processing($specs, $options, $dest2spec);
    croak 'argparse: ' .  $error if $error;

    $self->_apply_action($specs, $options, $dest2spec);
}

#
sub _post_parse_processing {
    my $self         = shift;
    my ($option_specs, $options, $dest2spec) = @_;

    #
    for my $spec ( @$option_specs ) {
        my $values = $options->{ $dest2spec->{$spec->{dest}} };

        # default
        if (!defined($self->namespace->get_attr($spec->{dest}))
                && scalar(@$values) < 1
                && defined($spec->{default}) )
        {
            if ($spec->{type} == TYPE_COUNT) {
                $self->namespace->set_attr($spec->{dest}, @{$spec->{default}});
            } elsif ($spec->{type} == TYPE_BOOL) {
                $self->namespace->set_attr($spec->{dest}, @{$spec->{default}});
            } elsif ($spec->{type} == TYPE_PAIR) {
                $self->namespace->set_attr($spec->{dest}, $spec->{default});
            } else {
                push @$values, @{$spec->{default}};
            }
        }

        # required
        return sprintf('%s is required', $spec->{dest}),
            if $spec->{required}
                && ! @$values
                && ! defined  $self->namespace->get_attr($spec->{dest});

        # split and expand
        # Pair are processed here as well
        if ( my $delimit = $spec->{split} ) {
            my @expanded;
            for my $v (@$values) {
                push @expanded,
                    map {
                        $spec->{type} == TYPE_PAIR ? { split('=', $_) } : $_
                    } split($delimit, $v);
            }

            $options->{ $dest2spec->{$spec->{dest} } } = \@expanded;
        } else {
            # Process PAIR only
            if ($spec->{type} == TYPE_PAIR) {
                $options->{ $dest2spec->{$spec->{dest} } }
                    = [ map { { split('=', $_) } } @$values ];
            }
        }

        # choices
        if ( $spec->{choices} ) {

            if (ref($spec->{choices}) eq 'CODE') {
                for my $v (@$values) {
                    $spec->{choices}->($v);
                }
            } else {
                my %choices =
                    map { defined($_) ? $_ : '_undef' => 1 }
                    @{$spec->{choices}};

              VALUE:
                for my $v (@$values) {
                    my $k = defined($v) ? $v : '_undef';
                    next VALUE if exists $choices{$k};

                    return sprintf(
                        "option %s value %s not in allowed choices: [ %s ]",
                        $spec->{dest}, $v, join( ', ', @{ $spec->{choices} } ),
                    );
                }
            }
        }

        if ( $spec->{choices_i} ) {
            my %choices =
                    map { defined($_) ? uc($_) : '_undef' => 1 }
                    @{$spec->{choices_i}};

          VALUE:
            for my $v (@$values) {
                my $k = defined($v) ? uc($v) : '_undef';
                next VALUE if exists $choices{$k};

                return sprintf(
                    "option %s value %s not in allowed choices: [ %s ] (case insensitive)",
                    $spec->{dest}, $v, join( ', ', @{ $spec->{choices_i} } ),
                );
            }
        }
    }

    return '';
}

sub _apply_action {
    my $self = shift;
    my ($specs, $options, $dest2spec) = @_;

   for my $spec (@$specs) {
        # Init
        # We want to preserve already set attributes if the namespace
        # is passed in.
        #
        # This is because one may want to load configs from a file
        # into a namespace and then use the same namespace for parsing
        # configs from command line.
        #
        $self->namespace->set_attr($spec->{dest}, undef)
            unless defined($self->namespace->get_attr($spec->{dest}));

        $spec->{action}->apply(
            $spec,
            $self->namespace,
            $options->{ $dest2spec->{$spec->{dest}} },
            $spec->{name},
        );
    }
}

#
#
#
#
#
sub usage {
    my $self = shift;

    $self->_sort_specs_by_groups() unless $self->{-groups};

    my $old_wrap_columns = $Text::Wrap::columns;

    my @usage;

    push @usage, sprintf('usage: %s', $self->prog);
    $Text::Wrap::columns = 80;
    push @usage, wrap('', '', $self->description);
    push @usage, '';

    for my $group ( sort keys %{ $self->{-groups} } ) {
        push @usage, @{ $self->group_usage($group) };
    }

    $Text::Wrap::columns = $old_wrap_columns; # restore to original

    push @usage, "\n";

    print STDERR join("\n", @usage);

    return \@usage;
}

sub _sort_specs_by_groups {
    my $self = shift;

    my $specs = $self->{-option_specs};

    for my $dest ( keys %{ $specs } ) {
        for my $group ( @{ $specs->{$dest}{groups} } ) {
            push @{ $self->{-groups}{$group}{-option} }, $specs->{$dest};
        }
    }

    $specs = $self->{-position_specs};

    for my $dest ( keys %{ $specs } ) {
        for my $group ( @{ $specs->{$dest}{groups} } ) {
            push @{ $self->{-groups}{$group}{-position} }, $specs->{$dest};
        }
    }
}

sub group_usage {
    my $self = shift;
    my $group = shift;

    unless ($self->{-groups}) {
        $self->_sort_specs_by_groups();
    }

    my $old_wrap_columns = $Text::Wrap::columns;
    $Text::Wrap::columns = 80;

    my @usage;

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } @{ $self->{-groups}{$group}{-option} || [] };

    my $flag_string = join(' ', map {
            ($_->{required} ? '' : '[')
            . join('|', @{$_->{flags}})
            . ($_->{required} ? '' : ']')
    } @option_specs);

    my @position_specs = sort {
        $a->{position} <=> $b->{position}
    } @{ $self->{-groups}{$group}{-position} || [] };

    my $position_string = join(' ', map {
            ($_->{required} ? '' : '[')
            . $_->{metavar}
            . ($_->{required} ? '' : ']')
    } @position_specs);

    if ($group) {
        push @usage, wrap('', '', $group . ': ' . ($self->{-group_description}{$group} || '')  );
    }

    push @usage, $position_string if $position_string;
    push @usage, $flag_string if $flag_string;

    if (@position_specs) {
        push @usage, 'positional arguments:';
        push @usage, @{ $self->_format_usage_by_spec(\@position_specs) };
    }

    if (@option_specs) {
        push @usage, 'optional arguments:';
        push @usage, @{ $self->_format_usage_by_spec(\@option_specs) };
    }

    push @usage, '';

    $Text::Wrap::columns = $old_wrap_columns; # restore to original

    return \@usage;
}

sub _format_usage_by_spec {
    my $self = shift;
    my $specs = shift;

    return unless $specs;

    my @usage;
    my $max = 10;
    my @item_help;

    for my $spec ( @$specs ) {
        my $item = sprintf(
            "%s",
            join(', ',  @{$spec->{flags}}),
            $spec->{metavar},
        );
        my $len = length($item);
        $max = $len if $len > $max;

        # flatterning default
        my $default = '';
        my $values = [];

        if (defined $spec->{default}) {
            if (ref $spec->{default} eq 'HASH') {
                while (my ($k, $v) = each %{$spec->{default}}) {
                    push @$values, "$k=$v";
                }
            } elsif (ref $spec->{default} eq "ARRAY") {
                $values = $spec->{default};
            } else {
                $values = [ $spec->{default} ];
            }
        }

        if (@$values) {
            $default = 'Default: ' . join(',', @$values);
        }

        push @item_help, [
            $item,
            ($spec->{required} ? ' ' : '?'),
            join("\n", ($spec->{help} || 'This is option ' . $spec->{dest}), $default),
        ];
    }

    $max *= -1;
    my $format = "    %${max}s    %s %s";
    $Text::Wrap::columns = 60;
    for my $ih (@item_help) {
        my $item_len = length($ih->[0]);
        # The prefixed whitespace in subsequent lines in the wrapped
        # help string
        my $sub_tab = " " x (-1 * $max + 4 + 4 + 2);
        my @help = split("\n", wrap('', '', $ih->[2]));

        my $help = (shift @help) || '' ;      # head
        $_ = $sub_tab . $_ for @help;         # tail

        push @usage, sprintf($format, $ih->[0], $ih->[1], join("\n", $help, @help));
    }

    return \@usage;
}

# translate option spec to the one accepted by
# Getopt::Long::GetOptions
sub _get_option_spec {
    my $class = shift;
    my $spec  = shift;

    my @flags = @{ $spec->{flags} };
    $_ =~ s/^-+// for @flags;
    my $name = join('|', @flags);
    my $type = 's';
    my $desttype = $spec->{type} == TYPE_PAIR() ? '%' : '@';

    my $optional_flag = '='; # not optional

    if ($spec->{type} == TYPE_SCALAR) {
        # pass
    } elsif ($spec->{type} == TYPE_ARRAY) {
        # pass
    } elsif ($spec->{type} == TYPE_PAIR) {
        # pass
    } elsif ($spec->{type} == TYPE_UNDEF) {
        $optional_flag = ':';
    } elsif ($spec->{type} == TYPE_BOOL) {
        $type = '';
        $optional_flag = '';
        $desttype = '';
    } elsif ($spec->{type} == TYPE_COUNT) {
        # pass
        $type = '';
        $optional_flag = '';
        $desttype = '+';
    } else {
        # pass
        # should never be here
        croak 'argparse: ' . 'Unknown type:' . ($spec->{type} || 'undef');
    }

    my $repeat = '';

    my $opt = join('', $name, $optional_flag, $type, $repeat, $desttype);

    return $opt;
}

1;

__END__