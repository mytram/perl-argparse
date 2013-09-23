package Getopt::ArgParse::Parser;

use Moo;

use Carp;
use Getopt::Long qw(GetOptionsFromArray);
use Text::Wrap;
use Scalar::Util qw(blessed);

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

	# Internal
    ERROR_PREFIX => 'Getopt::ArgParse: ',
};

# Allow customization
# default actions
my %Action2ClassMap = (
	'_store'       => 'Getopt::ArgParse::ActionStore',
    '_append'      => 'Getopt::ArgParse::ActionAppend',
    '_count'       => 'Getopt::ArgParse::ActionCount',
    # Not supported
    # '_help'        => 'Getopt::ArgParse::ActionHelp',
    # '_version'     => 'Getopt::ArgParse::ActionVersion',
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

#
has description => ( is => 'rw', required => 1, default => sub { '' }, );

#
has epilog => ( is => 'rw', required => 1, default => sub { '' }, );

has error_prefix => (is => 'rw', default => sub { ERROR_PREFIX() }, );

# namespace() - Read/write

# Contains the parsed results.
has namespace => (
    is => 'rw',
    isa => sub {
        return undef unless $_[0]; # allow undef
        my $class = blessed $_[0];
        die 'namespace doesn\'t comform to the required interface'
            unless $class && $class->can('set_attr') && $class->can('get_attr');
    },
);

# parent - Readonly

has parent => (
    is => 'ro',
       isa => sub {
           my $parent_class = blessed $_[0];
        die 'parent is not a Getopt::ArgParse::Parser'
            unless $parent_class && $parent_class->isa(__PACKAGE__);
    },
    required => 0,
);

# parser_configs - Read/write

# The configurations that will be passed to Getopt::Long::Configure(
# $self->parser_configs ) when parse_args is invoked.

has parser_configs => ( is => 'rw', required => 1, default => sub { [] }, );


# The current subcommand
has command => ( is => 'rw');

# internal properties
has _option_position => ( is => 'rw', required => 1, default => sub { 0 } );

sub BUILD {
    my $self = shift;

    $self->{-option_specs} = {};
    $self->{-position_specs} = {};

    $self->add_argument(
        '--help', '-h',
        type => 'Bool',
        dest => 'help',
        help => 'show this help message and exit',
    );

    # merge
    if ($self->parent) {
        $self->add_arguments( @ { $self->parent->{-pristine_add_arguments} || [] } );
    }
}

#
# subcommands
#
sub add_subparsers {
    my $self = shift;

    croak $self->error_prefix .  'incorrect number of arguments' if scalar(@_) % 2;

    my $args = { @_ };

    my $title = (delete $args->{title} || 'Subcommands') . ':';
    my $description = delete $args->{description} || '';

    croak $self->error_prefix . sprintf(
        'unknown parameters: %s',
        join(',', keys %$args)
    ) if keys %$args;

    if (exists  $self->{-subparsers}) {
        croak $self->error_prefix . 'subparsers already added';
    }

    $self->{-subparsers}{-title} = $title;
    $self->{-subparsers}{-description} = $description;

    $self->{-subparsers}{-alias_map} = {};

    my $hp = $self->add_parser(
        'help',
        help => 'display help information about ' . $self->prog,
    );

    $hp->add_argument(
        '--all', '-a',
        type => 'Bool',
    );

    $hp->add_argument(
        'command',
        nargs => 1,
    );

    return $self;
}

# $command, alias => [], help => ''
sub add_parser {
    my $self = shift;
    croak $self->error_prefix . 'add_subparsers() is not called first' unless $self->{-subparsers};

    my $command = shift;

    croak $self->error_prefix . 'subcommand is empty' unless $command;

    croak $self->error_prefix .  'incorrect number of arguments' if scalar(@_) % 2;


    if (exists $self->{-subparsers}{-parsers}{$command}) {
        croak $self->error_prefix . "subcommand $command already defined";
    }

    my $args = { @_ };

    my $help = delete $args->{help} || '';
    my $aliases = delete $args->{aliases} || [];
    croak $self->error_prefix . 'aliases is not an arrayref'
        if ref($aliases) ne 'ARRAY';

    for my $alias (@$aliases) {
        if (exists $self->{-subparsers}{-alias_map}{$alias}) {
            croak $self->error_prefix . "alias=$alias already used by command=" . $self->{-subparsers}{-alias_map}{$alias};
        }
        $self->{-subparsers}{-alias_map}{$alias} = $command;
    }

    croak $self->error_prefix . sprintf(
        'unknown parameters: %s',
        join(',', keys %$args)
    ) if keys %$args;

    $self->{-subparsers}{-alias_map}{$command} = $command;

    my $prog = $command;
    if (@$aliases) {
        $prog .= ' (' . join(', ', @$aliases) . ')';
    }

    return $self->{-subparsers}{-parsers}{$command} = __PACKAGE__->new(
        prog        => $prog,
        description => $help,
    );
}

# add_arguments([arg_spec], [arg_spec1], ...)
# Add multiple arguments.
# Interace method
sub add_arguments {
    my $self = shift;

    $self->add_argument(@$_) for @_;
}

# set_group
sub add_argument {
    my $self = shift;

    return unless @_; # mostly harmless

    #
    # FIXME: This is for merginng parent parents This is a dirty hack
    # and should be done properly by merging internal specs
    #
    push @{ $self->{-pristine_add_arguments} }, [ @_ ];

    my ($name, $flags, $rest) = $self->_parse_for_name_and_flags([ @_ ]);

    croak $self->error_prefix .  'incorrect number of arguments' if scalar(@$rest) % 2;

    croak $self->error_prefix .  'empty option name' unless $name;

    my $args = { @$rest };

    my @flags = @{ $flags };

    ################
    # type
    ################
    my $type_name = delete $args->{type} || 'Scalar';
    my $type = $Type2ConstMap{$type_name} if exists $Type2ConstMap{$type_name};

    croak $self->error_prefix . "unknown type=$type_name" unless defined $type;

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

        croak $self->error_prefix .  "Cannot load $action for action=$action_name" if $@;
    };

    ################
    # split
    ################
    my $split = delete $args->{split};
    if (defined $split && !$split && $split =~ /^ +$/) {
        croak $self->error_prefix .  'cannot use whitespaces to split';
    }

    if (defined $split && $type != TYPE_ARRAY && $type != TYPE_PAIR) {
        croak $self->error_prefix .  'split only for Array and Pair';
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
            croak $self->error_prefix .  'HASH default only for type Pair'
                if $type != TYPE_PAIR;
            $default = $val;
        } else {
            $default = [ $val ];
        }

        if ($type != TYPE_PAIR) {
            if ($type != TYPE_ARRAY && scalar(@$default) > 1) {
                croak $self->error_prefix . 'multiple default values for scalar type: $name';
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
        croak $self->error_prefix .  "must provide choices in an arrayref or a coderef";
    }

    my $choices_i = delete $args->{choices_i} || undef;

    if ($choices && $choices_i) {
        croak $self->error_prefix . 'not allow to specify choices and choices_i';
    }

    if (   $choices_i
        && ref($choices_i) ne 'ARRAY' )
    {
        croak $self->error_prefix .  "must provide choices_i in an arrayref";
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
                   croak $self->error_prefix .  "flag $f already used for a different option ($d)"
                        if grep { $f eq $_ } @{$s->{flags}};
                }
            }
        }

        if (exists $self->{-position_specs}{$dest}) {
            croak $self->error_prefix . "dest=$dest already used by a positional argument";
        }
    } else {
        if (exists $self->{-option_specs}{$dest}) {
            croak $self->error_prefix . "dest=$dest already used by an optional argument";
        }
    }

    ################
    # nargs - positional only
    ################

    my $nargs = delete $args->{nargs};

    if (defined $nargs ) {
        croak $self->error_prefix . 'nargs only allowed for positional options' if @flags;

        if (   $type != TYPE_PAIR
            && $type != TYPE_ARRAY
            && $nargs ne '1'
            && $nargs ne '?'
        ) {
            $type = TYPE_ARRAY;
        }
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
        position  => $self->{-option_position}++, # sort order
        groups    => [ '' ],
    };

    my $specs;
    if (@flags) {
        $specs = $self->{-option_specs};
    } else {
        $specs = $self->{-position_specs};
    }

    # reset
    if (delete $args->{reset}) {
        $self->namespace->set_attr($spec->{type}, undef) if $self->namespace;
        delete $specs->{$spec->{dest}};
    }

    croak $self->error_prefix . sprintf(
        'unknown spec parameters: %s',
        join(',', keys %$args)
    ) if keys %$args;

    # type check
    if (exists $specs->{$spec->{dest}}{type}
            && $specs->{$spec->{dest}}{type} != $spec->{type}) {
        croak $self->error_prefix . sprintf(
            'not allow to override %s with different type',
            $spec->{dest},
        );
    }

    # override
    $specs->{$spec->{dest}} = $spec;

    # specs changed, need to force to resort specs by groups
    delete $self->{-groups} if $self->{-groups};

    return $self;
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

#
# parse_args([@_])
#
# Parse @ARGV if called without passing arguments. It returns an
# instance of ArgParse::Namespace upon success
#
# Interface

sub parse_args {
    my $self = shift;

    my @argv = scalar(@_) ? @_ : @ARGV;

    $self->{-saved_argv} = \@ARGV;
    @ARGV = ();

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-option_specs}};

    my @position_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-position_specs}};

    $self->namespace(Getopt::ArgParse::Namespace->new) unless $self->namespace;

    $self->{-argv} = \@argv;

    my $parsed_subcmd;
    # If the first argument is a subcommnd, it will parse as a subcommand
    if (exists $self->{-subparsers}) {
        $parsed_subcmd = $self->_parse_subcommand();
    }

    if (!$parsed_subcmd) {
        $self->_parse_optional_args(\@option_specs) if @option_specs;
        $self->_parse_positional_args(\@position_specs) if @position_specs;

        if ($self->namespace->get_attr('help')) {
            $self->print_usage();
            exit(0);
        }
    } else {
        if ($self->command() eq 'help') {
            if ($self->namespace->command) {
                my $usage = $self->format_command_usage($self->namespace->command);
                if ($usage) {
                    print STDERR $_, "\n" for @$usage;
                    exit(0);
                } else {
                    croak $self->error_prefix . sprintf('No help for %s. See help', $self->namespace->get_attr('command'));
                }
            } else {
                $self->print_usage();
                exit(0);
            }
        }
    }

    return $self->namespace;
}

sub _subcommand_parser {
    my $self = shift;
    my $alias = shift;

    return unless $alias;

    my $command = $self->{-subparsers}{-alias_map}{$alias}
        if exists $self->{-subparsers}{-alias_map}{$alias};

    return unless $command;

    $self->command($command);
    # The subcommand parser must exist if the alias is mapped
    return $self->{-subparsers}{-parsers}{$command};
}

sub _parse_subcommand {
    my $self = shift;

    my $alias = $self->{-argv}->[0];
    return unless $alias;

    return if index($alias, '-', 0) == 0;

    shift @{$self->{-argv}};

    # Subcommand must appear as the first argument
    # or it will parse as the top command

    my $subp = $self->_subcommand_parser($alias);
    croak $self->error_prefix . sprintf("$alias is not a %s command. See help", $self->prog) unless $subp;

    $subp->namespace($self->namespace);
    $subp->parse_args( @{$self->{-argv}} );

    $self->{-argv} = $subp->{-argv};

    return 1;
}

#
# After each call of parse_args(), call this to retrieve any
# unconsumed arguments
#
sub argv {
    my @argv = @{ $_[0]->{-argv} || [] };
    wantarray ? @argv  : \@argv;
}

sub _parse_optional_args {
    my $self = shift;
    my $specs = shift;
    my $options   = {};
    my $dest2spec = {};

    for my $spec ( @$specs ) {
        my @values;
        $dest2spec->{$spec->{dest}} = $self->_get_option_spec($spec);
        if (    $spec->{type} == TYPE_ARRAY
             || $spec->{type} == TYPE_COUNT
             || $spec->{type} == TYPE_PAIR
             || $spec->{type} == TYPE_SCALAR
         ) {
            my @values;
            $options->{ $dest2spec->{$spec->{dest}} } = \@values;
        } else {
            my $value;
            $options->{ $dest2spec->{$spec->{dest}} } = \$value;
        }
    }

    Getopt::Long::Configure( @{ $self->parser_configs });

    {
        my $warn;
        local $SIG{__WARN__} = sub { $warn = shift };

        my $result = GetOptionsFromArray( $self->{-argv}, %$options );

        if ($warn || !$result) {
            croak $self->error_prefix .  "$warn";
        }
    }

    Getopt::Long::Configure('default');

    my $error = $self->_post_parse_processing( $specs, $options, $dest2spec );

    croak $self->error_prefix .  $error if $error;

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
            croak $self->error_prefix .  'Bool not allowed for positional arguments';
        }

        my $number = 1;
        my $nargs = defined $spec->{nargs} ? $spec->{nargs} : 1;
        if (defined $spec->{nargs}) {
            if ($nargs eq '?') {
                $number = 1;
            } elsif ($nargs eq '+') {
                croak $self->error_prefix . "too few arguments: narg='+'" unless @{$self->{-argv}};
                $number = scalar @{$self->{-argv}};
            } elsif ($nargs eq '*') { # remainder
                $number = scalar @{$self->{-argv}};
            } elsif ($nargs !~ /^\d+$/) {
                croak $self->error_prefix .  'invalid nargs:' . $nargs;
            } else {
                $number = $nargs;
            }
        }

        push @$values, splice(@{$self->{-argv}}, 0, $number) if @{$self->{-argv}};

        # If no values, let it pass for required checking
        # If there are values, make sure there is the right number of
        # values
        if (scalar(@$values) && scalar(@$values) != $number) {
            croak($self->error_prefix . sprintf(
                    'too few arguments for %s: expected:%d,actual:%d',
                    $spec->{dest}, $number, scalar(@$values),
                )
            );
        }
    }

    my $error = $self->_post_parse_processing($specs, $options, $dest2spec);
    croak $self->error_prefix .  $error if $error;

    $self->_apply_action($specs, $options, $dest2spec);
}

#
sub _post_parse_processing {
    my $self         = shift;
    my ($option_specs, $options, $dest2spec) = @_;

    #
    for my $spec ( @$option_specs ) {
        my $values = $options->{ $dest2spec->{$spec->{dest}} };

        if (defined($values)) {
            if (ref $values eq 'SCALAR') {
                if (defined($$values)) {
                    $values = [ $$values ];
                } else {
                    $values = [];
                }
            }
        } else {
            $values = [];
        }

        $options->{ $dest2spec->{$spec->{dest}} } = $values;

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
                && ($spec->{type} != TYPE_BOOL && $spec->{type} != TYPE_COUNT)
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
sub print_usage {
    my $self = shift;

    print STDERR $_, "\n" for @{$self->format_usage};
}

sub format_usage {
    my $self = shift;

    $self->_sort_specs_by_groups() unless $self->{-groups};

    my $old_wrap_columns = $Text::Wrap::columns;

    my @usage;

    push @usage, wrap('', '', $self->prog. ': ' . $self->description);

    my ($help, $option_string) =  $self->_format_group_usage();
    $Text::Wrap::columns = 80;

    my $header = sprintf(
        'usage: %s %s',
        $self->prog, $option_string
    );

    push @usage, wrap('', '', $header);

    push @usage, '';

    push @usage, @$help;

    if (exists $self->{-subparsers}) {
        push @usage, wrap('', '', $self->{-subparsers}{-title});
        push @usage, wrap('', '', $self->{-subparsers}{-description}) if $self->{-subparsers}{-description};

        for my $parser ( values %{$self->{-subparsers}{-parsers}} ) {
            push @usage, sprintf('  %-12s%s', $parser->prog, $parser->description);
            # FIXME - folding description
        }
    }

    $Text::Wrap::columns = $old_wrap_columns; # restore to original

    push @usage, '';

    return \@usage;
}

sub format_command_usage {
    my $self = shift;
    my $alias = shift;

    my $subp = $self->_subcommand_parser($alias);
    return '' unless $subp;

    return $subp->format_usage();
}

# FIXME: Maybe we should remove this grouping thing
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

sub _format_group_usage {
    my $self = shift;
    my $group = '';
    # my $group = shift || '';

    unless ($self->{-groups}) {
        $self->_sort_specs_by_groups();
    }

    my $old_wrap_columns = $Text::Wrap::columns;
    $Text::Wrap::columns = 80;

    my @usage;

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } @{ $self->{-groups}{$group}{-option} || [] };

    my @flag_items = map {
            ($_->{required} ? '' : '[')
            . join('|', @{$_->{flags}})
            . ($_->{required} ? '' : ']')
    } @option_specs;

    my @position_specs = sort {
        $a->{position} <=> $b->{position}
    } @{ $self->{-groups}{$group}{-position} || [] };

    my @position_items = map {
            ($_->{required} ? '' : '[')
            . $_->{metavar}
            . ($_->{required} ? '' : ']')
    } @position_specs;

    my @subcommand_items = ('<command>', '[<args>]') if exists $self->{-subparsers};

    if ($group) {
        push @usage, wrap('', '', $group . ': ' . ($self->{-group_description}{$group} || '')  );
    }

    # push @usage, wrap('', '', $position_string) if $position_string;
    # push @usage, wrap('', '', $flag_string) if $flag_string;

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

    return ( \@usage, join(' ', @position_items, @flag_items, @subcommand_items) ) ;
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
            "%s %s",
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
    my $self = shift;
    my $spec  = shift;

    my @flags = @{ $spec->{flags} };
    $_ =~ s/^-+// for @flags;
    my $name = join('|', @flags);
    my $type = 's';
    my $desttype = '';

    my $optional_flag = '='; # not optional

    if ($spec->{type} == TYPE_SCALAR) {
        $desttype = '@';
    } elsif ($spec->{type} == TYPE_ARRAY) {
        $desttype = '@';
    } elsif ($spec->{type} == TYPE_PAIR) {
        $desttype = '@';
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
        croak $self->error_prefix . 'unknown type:' . ($spec->{type} || 'undef');
    }

    my $repeat = '';

    my $opt = join('', $name, $optional_flag, $type, $repeat, $desttype);

    return $opt;
}

1;

__END__
