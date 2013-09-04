require 5.008001;

package ArgParse::ArgumentParser;
{
    $ArgParse::ArgumentParser::VERSION = '0.01';
}

use Moo;
use Carp;

use Text::Wrap;

use ArgParse::Namespace;

use Getopt::Long qw(GetOptionsFromArray);

use constant {
    TYPE_UNDEF   => 0,
    TYPE_STRING  => 1,
    TYPE_INTEGER => 2,
    TYPE_FLOAT   => 3,
    TYPE_PAIR	 => 4, # key=value pair
    TYPE_BOOL	 => 5,

    CONST_TRUE   => 1,
    CONST_FALSE  => 0,
};

my %Action2ClassMap = (
	'store'       => 'ArgParse::ActionStore',
    'append'      => 'ArgParse::ActionAppend',
    'count'       => 'ArgParse::ActionCount',
    'help'        => 'ArgParse::ActionHelp',
    'version'     => 'ArgParse::ActionVersion',
);

my %Type2ConstMap = (
    ''        => TYPE_UNDEF(),
    'Int'     => TYPE_INTEGER(),
    'Str'     => TYPE_STRING(),
    'Pair'    => TYPE_PAIR(),
    'Bool'    => TYPE_BOOL(),
);

=item prog() - Read/write

Program name. Default $0

=cut

has prog => ( is => 'rw', required => 1, default => sub { $0 }, );

=item description() - Read/write

The description of the progam

=cut

has description => ( is => 'rw', required => 1, default => sub { '' }, );

=item namespace() - Read/write

Contains the parsed results.

=cut

has namespace => ( is => 'rw', required => 1, default => sub { ArgParse::Namespace->new }, );

=item parent - Readonly

=cut

has parent => (
    is => 'ro',
       isa => sub {
           my $parent_class = ref $_[0] || $_[0];
        die 'Parent must be an ArgumentParser'
            unless $parent_class->isa(__PACKAGE__);
    },
    required => 0,
);

=item parser_configs - Read/write

The configurations that will be passed to Getopt::Long::Configure(
$self->parser_configs ) when parse_args is invoked.

=cut

has parser_configs => ( is => 'rw', required => 1, default => sub { [] }, );

# internal properties
has _option_position => ( is => 'rw', required => 1, default => sub { 0 } );

sub BUILD {
    my $self = shift;

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

=head3 add_arguments([arg_spec], [arg_spec1], ...)

Add multiple arguments.

=cut

sub add_arguments {
    my $self = shift;

    $self->add_argument(@$_) for @_;
}

#
# add_argument()
#
#    name or flags - Either a name or a list of option strings, e.g. foo or -f, --foo.
#    action        - The basic type of action to be taken when this argument
#                    is encountered at the command line.
#    split         - a string by which to split the argument string e.g. a,b,c
#                    will be split into [ 'a', 'b', 'c' ] if split => ','
#    default       - The value produced if the argument is absent from the command line.
#    type          - The type to which the command-line argument should be converted.
#    choices       - A container of the allowable values for the argument.
#    required      - Whether or not the command-line option may be omitted (optionals only).
#    help          - A brief description of what the argument does.
#    metavar       - A name for the argument in usage messages.
#    dest          - The name of the attribute to be added to the object returned by parse_args().
#

sub add_argument {
    my $self = shift;

    return unless @_; # mostly harmless

    push @{ $self->{-pristine_add_arguments} }, [ @_ ];

    my ($name, $flags, $rest) = $self->_parse_args_for_name_and_flags([ @_ ]);

    croak "Incorrect arguments" if scalar(@$rest) % 2;

    my $args = { @$rest };

    croak "Must provide at least one non-empty argument name" unless $name;

    my @flags = @{ $flags || [] };

    ################
    # type
    ################
    my $type_name = $args->{type} || '';
    my $type = $Type2ConstMap{$type_name} if exists $Type2ConstMap{$type_name};

    croak "Unknown type: $type_name" unless defined $type;

    if ($type == TYPE_BOOL) {
        if (!defined $args->{default}) {
            $args->{default} = 0; # False if unspecified, or True
        }
    }

    ################
    # action
    ################
    my $action_name = $args->{action} || 'store';

    my $action = $Action2ClassMap{$action_name}
        if exists $Action2ClassMap{$action_name};

    $action = $action_name unless $action;

    {
        local $SIG{__WARN__};
        local $SIG{__DIE__};

        eval "require $action";

        croak "Cannot find the module for action $action" if $@;
    };

    ################
    # split
    ################
    my $split = $args->{split};
    if (defined $split && !$split && $split =~ /^ +$/) {
        croak 'cannot split arguments on whitespaces';
    }

    ################
    # default
    ################
    my $default;
    if (exists $args->{default}) {
        my $val = $args->{default};
        if (ref($val) eq 'ARRAY') {
            $default = $val;
        } elsif (ref($val) eq 'HASH') {
            croak 'Cannot use HASH default for non-hash type options'
                if $type != TYPE_PAIR;
            $default = $val;
        } else {
            $default = [ $val ];
        }
    } else {
        $default = [];
    }

    ################
    # choices
    ################
    my $choices = $args->{choices} || undef;
    if (  $choices
       && (ref($choices) eq 'CODE' || ref($choices) eq 'ARRAY')
    ) {
        croak "Must provice choices in an array ref or a coderef";
    }

    ################
    # required
    ################
    my $required = $args->{required} || '';

    ################
    # help
    ################
    my $help = $args->{help} || '';

    ################
    # metavar
    ################
    my $metavar = $args->{metavar} || uc($name);

    $metavar = ''
        if $type == TYPE_BOOL
            || $action_name eq 'count';

    ################
    # dest
    ################
    my $dest = $args->{dest} || $name;
    $dest =~ s/-/_/g; # option-name becomes option_name

    if (@flags) {
        while (my ($d, $s) = each %{$self->{-option_specs}}) {
            if ($dest ne $d) {
                for my $f (@flags) {
                   croak "$f already used for a different option ($d)"
                        if grep { $f eq $_ } @{$s->{flags}};
                }
            }
        }
    }

    # never modify existing ones so that the parent's structure will
    # not be modified
    my $spec = {
        name     => $name,
        flags    => \@flags,
        action   => $action,
        split    => $args->{split},
        required => $args->{required} || '',
        type     => $type,
        default  => $default,
        choices  => $choices,
        dest     => $dest,
        metavar  => $metavar,
        help     => $help,
        position => $self->{-option_position}++, # sort order
    };

    # override
    if (@flags) {
        $self->{-option_specs}{$spec->{dest}} = $spec;
    } else {
        $self->{-position_specs}{$spec->{dest}} = $spec;

        # TODO
        croak "Postional arguments are not supported yet!"
    }

    return $self;
}

sub _parse_args_for_name_and_flags {
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

sub parse_args {
    my $self = shift;

    my @saved_argv = @ARGV;

    my @argv = scalar(@_) ? @_ : @ARGV;

    unless (@argv) {
        my $usage = $self->usage();
        exit(0);
    }

    my $namespace = $self->namespace;

    Getopt::Long::Configure( @{ $self->parser_configs } );

    my $options   = {};
    my $dest2spec = {};

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-option_specs}};

    for my $spec ( @option_specs ) {
        my @values =  ();
        $dest2spec->{$spec->{dest}} = $self->_get_option_spec($spec);
        $options->{ $dest2spec->{$spec->{dest}} } = \@values;
    }

    {
        my $warn;
        local $SIG{__WARN__} = sub { $warn = shift };

        my $result = GetOptionsFromArray( \@argv, %$options );

        if ($warn || !$result) {
            croak "Getoptions error: $warn";
        }
    }

    my $error = $self->_post_parse_processing( \@option_specs, $options, $dest2spec );

    croak $error if $error;

    # action
    for my $spec (@option_specs) {
        # Init
        # We want to preserve already set attributes if the namespace
        # is passed in
        $namespace->set_attr($spec->{dest}, undef)
            unless defined($namespace->get_attr($spec->{dest}));

        my $action = $spec->{action};

        $action->apply(
            $spec,
            $namespace,
            $options->{ $dest2spec->{$spec->{dest}} },
            $spec->{name}
        );
    }

    # positional arguments
    $self->{-argv} = \@argv;

    Getopt::Long::Configure('default');

    if ($namespace->get_attr('help')) {
        my $usage = $self->usage();
        exit(0);
    }

    # parse positional

    return $namespace;
}

sub _parse_positional_args {
    my $self = shift;
    #
}

sub _post_parse_processing {
    my $self         = shift;
    my $option_specs = shift;
    my $options      = shift;
    my $dest2spec    = shift;

    #
    for my $spec ( @$option_specs ) {
        my $values = $options->{ $dest2spec->{$spec->{dest}} };

        # default
        if ( scalar(@$values) < 1 && $spec->{default} ) {
            push @$values, @{$spec->{default}} unless $spec->{type} == TYPE_BOOL;
        }

        # required
        return sprintf('%s is required', $spec->{dest}),
            if $spec->{required} && ! @$values;

        # type check

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

        # TODO
        # type convert
    }

    return '';
}


sub usage {
    my $self = shift;

    my $old_wrap_columns = $Text::Wrap::columns;

    my @usage;

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{ $self->{-option_specs} || {} };

    my $flag_string = join(' ', map {
        ($_->{required} ? '' : '[')
        . join('|', @{$_->{flags}})
        . ($_->{required} ? '' : ']')
    } @option_specs);

    push @usage, sprintf('usage: %s %s', $self->prog, $flag_string);
    $Text::Wrap::columns = 80;
    push @usage, wrap('', '', $self->description);

    push @usage, "\n";

    # TODO
    push @usage, 'positional arguments:' if exists $self->{-position_specs};
    push @usage, 'optional arguments:' if exists $self->{-option_specs};

    my $max = 10;
    my @item_help;
    for my $spec (@option_specs) {
        my $item = sprintf("%s %s", join(', ',  @{$spec->{flags}}), $spec->{metavar});
        my $len = length($item);
        $max = $len if $len > $max;
        push @item_help, [ $item, $spec->{help} ];
    }

    $max *= -1;
    my $format = "    %${max}s    %s";
    $Text::Wrap::columns = 60;
    for my $ih (@item_help) {
        my $item_len = length($ih->[0]);
        # The prefixed whitespace in subsequent lines in the wrapped
        # help string
        my $sub_tab = " " x (-1 * $max + 4 + 4);
        my @help = split("\n", wrap('', '', $ih->[1]));

        my $help = (shift @help) || '' ;      # head
        $_ = $sub_tab . $_ for @help; # tail

        push @usage, sprintf($format, $ih->[0], join("\n", $help, @help));
    }

    $Text::Wrap::columns = $old_wrap_columns; # restore to original

    push @usage, "\n";

    print STDERR join("\n", @usage);

    return \@usage;
}

# TODO - Not used
# string to number
#
sub _ston {
    my $self = shift;
    my $s = shift;

    return 0.0 unless $s;

    my $f = $s;
    {
        my $warn;
        local $SIG{__WARN__} = sub { $warn = shift; };
        $f += 0.0;
        croak "$s is not a number";
    }

    return $f;
}

# translate option spec to the one accepted by
# Getopt::Long::GetOptions
sub _get_option_spec {
    my $class = shift;
    my $spec  = shift;

    my @flags = @{ $spec->{flags} };
    $_ =~ s/^-+// for @flags;
    my $name = join('|', @flags);
    my $type = '';
    my $desttype = $spec->{type} == TYPE_PAIR() ? '%' : '@';

    my $optional_flag = '='; # not optional

    if ($spec->{type} == TYPE_INTEGER) {
        $type = 'o';
    } elsif ($spec->{type} == TYPE_STRING) {
        $type = 's';
    } elsif ($spec->{type} == TYPE_FLOAT) {
        $type = 'f';
    } elsif ($spec->{type} == TYPE_PAIR) {
        $type = 's';
    } elsif ($spec->{type} == TYPE_UNDEF) {
        $type = 's';
        $optional_flag = ':';
    } elsif ($spec->{type} == TYPE_BOOL) {
        $type = '';
        $optional_flag = '';
        $desttype = '';
    } else {
        # pass
        # should never be here
    }

    my $repeat = '';

    my $opt = join('', $name, $optional_flag, $type, $repeat, $desttype);

    return $opt;
}

1;
