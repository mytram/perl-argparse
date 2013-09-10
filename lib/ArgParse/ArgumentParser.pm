require 5.008001;

package ArgParse::ArgumentParser;
{
    $ArgParse::ArgumentParser::VERSION = '0.01';
}

use Moo;

use Carp;
use Getopt::Long qw(GetOptionsFromArray);
use Text::Wrap;

use ArgParse::Namespace;

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
	'_store'       => 'ArgParse::ActionStore',
    '_append'      => 'ArgParse::ActionAppend',
    '_count'       => 'ArgParse::ActionCount',
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
        croak 'argparse: ' .  "Must provide a Namespace" unless $class->isa('ArgParse::Namespace');
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
    my $type_name = $args->{type} || '';
    my $type = $Type2ConstMap{$type_name} if exists $Type2ConstMap{$type_name};

    croak 'argparse: ' .  "Unknown type: $type_name" unless defined $type;

    if ($type == TYPE_BOOL) {
        if (!defined $args->{default}) {
            $args->{default} = 0; # False if unspecified, or True
        }
    } elsif ($type == TYPE_COUNT) {
        $args->{action} = '_count' unless defined $args->{action};
    } elsif ($type == TYPE_ARRAY || $type == TYPE_PAIR) {
        $args->{action} = '_append' unless defined $args->{action};
    } else {
        # pass
    }

    ################
    # action
    ################
    my $action_name = $args->{action} || '_store';

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
    my $split = $args->{split};
    if (defined $split && !$split && $split =~ /^ +$/) {
        croak 'argparse: ' .  'cannot split arguments on whitespaces';
    }

    if (defined $split && $type != TYPE_ARRAY && $type != TYPE_PAIR) {
        croak 'argparse: ' .  'Only allow split to be used with either Array or Pair type';
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
            croak 'argparse: ' .  'Cannot use HASH default for non-hash type options'
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
    if (   $choices
        && ref($choices) ne 'CODE'
        && ref($choices) ne 'ARRAY' )
    {
        croak 'argparse: ' .  "Must provide choices in an arrayref or a coderef";
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
            || $action_name eq '_count';

    ################
    # dest
    ################
    my $dest = $args->{dest} || $name;
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
    }

    # never modify existing ones so that the parent's structure will
    # not be modified
    my $spec = {
        name     => $name,
        flags    => \@flags,
        action   => $action,
        nargs	 => $args->{nargs},
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
    }

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

    unless (@argv) {
        my $usage = $self->usage();
        exit(0);
    }

    my $namespace = $self->namespace || ArgParse::Namespace->new;
    $self->namespace($namespace);

    $self->{-argv} = \@argv;

    $self->_parse_optional_args();

    $self->_parse_positional_args();

    if ($namespace->get_attr('help')) {
        my $usage = $self->usage();
        exit(0);
    }

    return $namespace;
}

sub _parse_optional_args {
    my $self = shift;

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

        my $result = GetOptionsFromArray( $self->{-argv}, %$options );

        if ($warn || !$result) {
            croak 'argparse: ' .  "Getoptions error: $warn";
        }
    }

    Getopt::Long::Configure('default');

    my $error = $self->_post_parse_processing( \@option_specs, $options, $dest2spec );

    croak 'argparse: ' .  $error if $error;

    $self->_apply_action(\@option_specs, $options, $dest2spec);
}

sub _parse_positional_args {
    my $self = shift;
    my $options   = {};
    my $dest2spec = {};

    my @specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-position_specs}};

  POSITION_SPEC:
    for my $spec (@specs) {
        $dest2spec->{$spec->{dest}} = $spec->{dest};
        my @values = ();
        # Always assigne values to an option
        $options->{$spec->{dest}} = \@values;

        next unless @{$self->{-argv}};

        if ($spec->{type} == TYPE_BOOL) {
            croak 'argparse: ' .  'Bool not allowed for positional arguments';
        }

        my $number = 1;
        if (defined $spec->{nargs}) {
            my $nargs = $spec->{nargs};
            if ($nargs eq '?') {
                $number = 1;
            } elsif ($nargs eq '+') {
                $number = 1;
                croak 'argparse: ' .  "too few arguments: narg='+'" unless @{$self->{-argv}};
            } elsif ($nargs eq '*') { # remainder
                $number = scalar @{$self->{-argv}};
            } elsif ($nargs !~ /^\d*$/) {
                croak 'argparse: ' .  'invalid nargs';
            } else {
                $number = $nargs;
            }
        }

        if (scalar(@{$self->{-argv}})) {
            push @values, splice(@{$self->{-argv}}, 0, $number);
        }
    }

    my $error = $self->_post_parse_processing(\@specs, $options, $dest2spec);
    croak 'argparse: ' .  $error if $error;

    $self->_apply_action(\@specs, $options, $dest2spec);
}

sub _post_parse_processing {
    my $self         = shift;
    my ($option_specs, $options, $dest2spec) = @_;

    #
    for my $spec ( @$option_specs ) {
        my $values = $options->{ $dest2spec->{$spec->{dest}} };

        # default
        if ( scalar(@$values) < 1 && $spec->{default} ) {
            push @$values, @{$spec->{default}} unless $spec->{type} == TYPE_BOOL;
        }

        # required
        return sprintf('%s is required', $spec->{dest}),
            if $spec->{required}
                && ! @$values
                && ! defined $self->namespace->get_attr($spec->{dest});

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
            $spec->{name}
        );
    }
}

# TODO: show required, default
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
    if (exists $self->{-position_specs}) {
        push @usage, 'positional arguments:';
        push @usage, @{ $self->_format_usage_by_spec( $self->{-position_specs} ) };
    }

    if ( exists $self->{-option_specs} ) {
        push @usage, 'optional arguments:';
        push @usage, @{ $self->_format_usage_by_spec( $self->{-option_specs} ) };
    }

    $Text::Wrap::columns = $old_wrap_columns; # restore to original

    push @usage, "\n";

    print STDERR join("\n", @usage);

    return \@usage;
}

sub _format_usage_by_spec {
    my $self = shift;
    my $specs = shift;

    my @usage;
    my $max = 10;
    my @item_help;

    for my $spec (@$specs) {
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

# perldoc

=pod

=head1 NAME

ArgParse::ArgumentParser - A Perl's Argument Parser

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use ArgParse::ArgumentParser;

 $ap = ArgParse::ArgumentParser->new(
 	prog        => 'MyProgramName',
 	description => 'This is a program',
 );

 # Parse an option: '--foo value' or '-f value'
 $ap->add_argument('--foo', '-f', required => 1);

 # Parse a boolean: '--bool' or '-b' using a different name from
 # the option
 $ap->add_argument('--bool', '-b', type => 'Bool', dest => 'boo');

 # Parse a positonal option
 $ap->add_arguement('command', required => 1);

 # $ns is also accessible via $ap->namespace
 my $ns = $ap->parse_args(split(' ', 'test -f 1 -b');

 say $ns->command; # 'test'
 say $ns->foo;     # 1
 say $ns->boo      # 1
 say $ns->no_boo   # 0 - 'no_' is added for boolean options

 # You can continue to add arguments and parse them again
 # $ap->namespace is accumulatively populated

 # Parse an Array type option and split the value into an array of values
 $ap->add_argument('--emails', type => 'Array', split => ',');
 $ns = $ap->parse_args(split(' ', '--emails a@perl.org,b@perl.org,c@perl.org'));
 # Because this is an array option, this allows you to specify the
 # option multiple times
 $ns = $ap->parse_args(split(' ', '--emails a@perl.org,b@perl.org --emails c@perl.org'));
 say join('|', $ns->emails); # a@perl.org|b@perl.org|c@perl.org

 # Parse an option as key,value pairs
 $ap->add_argument('--param', type => 'Pair', split => ',');
 $ns = $ap->parse_args(split(' ', '--param a=1,b=2,c=3'));

 say $ns->param->{a}; # 1
 say $ns->param->{b}; # 2
 say $ns->param->{c}; # 3

 # You can use choice to restrict values
 $ap->add_arguemnt('--env', choices => [ 'dev', 'prod' ]);

 # or use case-insensitive choices
 # Override the previous option
 $ap->add_arguemnt('--env', choices_i => [ 'dev', 'prod' ]);

 # or use a coderef
 # Override the previous option
 $ap->add_argument(
 	'--env',
 	choices => sub {
 		die "--env invalid values" if $_[0] !~ /^(dev|prod)$/i;
 	},
 );

=head1 DESCRIPTIOIN

ArgParse::ArgumentParser and related classes together aim to provide
user-friendly interfaces for writing command-line interfaces. A user
should be able to use it without looking up the document most of the
time. It allows applications to define argument specifications and it
will parse them out of @AGRV by default or a command line if
provided. It implements both optional arguments, using Getopt::Long
for parsing, and positional arguments. The class also generates help
and usage messages.

The parser has a namespace property, which is an object of
ArgParser::Namespace. The parsed argument values are stored in this
namespace property. Moreover, the values are stored accumulatively
when parse_args() is called multiple times.

Though inspired by Python's argparse and names and ideas are borrowed
from it, it doesn't work exactly the same as argparse .

ArgParse::ArgumentParser is a Moo class.

=head2 METHODS

=head3 Constructor

ArgParse::ArgumentParser->new( ... )

This will create a new parser. It accepts the following parameters.

=over 8

=item * prog

The program's name. Default $0.

=item * description

A description of the program.

=item * namespace

An object of ArgParse::Namespace. An empty namespace is created if
not provided. The parsed values are stored in it, and they can be
refered to by their argument names as the namespace's properties,
e.g. $parser->namespace->boo. See also ArgParse::Namespace

=item * parser_configs

The Getopt::Long configurations. See also Getopt::Long

=item * parent

Another parser, whose argument specifications the new parse will
inherit.

=back

=head3 add_argument( ... )

This object method defines the specfication of an argument. It accepts
the following parameters.

=over 8

=item * name or flags

Either a name or a list of option strings, e.g. foo or -f, --foo.

If dest is not specified, the name or the first option without leading
dashes will be used as the name for retrieving values. If a name is
given, this argument is a positional argument. Otherwise, it's an
option argument.

Hyphens can be used in names and flags, but they will be replaced with
underscores '_' when used as option names. For example:

    $parser->add_argument('--dry-run', type => 'Bool');
    # command line: prog --dry-run
    $parser->namespace->dry_run; # The option's name is dry_run

A name or option strings are following by named paramters.

=item * dest

The name of the attribute to be added to the namespace populated by
parse_args().

=item * type => $type

Specify the type of the argument. It can be one of the following values:

=over 8

=item * Scalar

The option takes a scalar value.

=item * Array

The option takes a list of values. The option can appear multiple
times in the command line. Each value is appended to the list. It's
stored in an arrayref in the namespace.

=item * Pair

The option takes a list of key-value pairs separated by the equal sign
'='. It's stored in a hashref in the namespace.

=item * Bool

The option does not take an argument. It's set to true if the option
is present or false otherwise. A 'no_bool' option is also available,
which is the negation of bool().

For example:

    $parser->add_argument('--dry-run', type => 'Bool');

    $ns = $parser->parse_args(split(' ', '--dry-run'));

    print $ns->dry_run; # true
    print $ns->no_dry_run; # false

=item * Count

The option does not take an argument and its value will be incremented
by 1 every time it appears on the command line.

=back

=item * split

split should work with types 'Array' and 'Pair' only.

split specifies a string by which to split the argument string e.g. if
split => ',', a,b,c will be split into [ 'a', 'b', 'c' ].When split
works with type 'Pair', the parser will split the argument string and
then parse each of them as pairs.

=item * choices

Specify A list of the allowable values for the argument or a
subroutine that validates input values.

=item * default

The value produced if the argument is absent from the command line.

=item * required

Whether or not the command-line option may be omitted (optionals only).

=item * help

A brief description of what the argument does.

=item * metavar

A name for the argument in usage messages.

=item * nargs - Positional option only

=over 8

=item * n (1 if not specified)

=item * ?

=item * *

=back

=back

=head3 parse_args( ... )

This object method accepts a list of arguments or @ARGV if
unspecified, parses them for values, and stores the values in the
namespace object.

It displays a generated usage message if both @ARGV and argument list
are empty.

=head4 The namespace object is accumulatively poplulated

If parse_args() is called multiple times to parse a number of command
lines, the same namespace object is accumulatively populated.  For
Scalar and Bool options, this means the previous value will be
overwrittend. For Pair and Array options, values will be appended. And
for a Count option, it will add on top of the previous value.

In face, the program can choose to pass a already populated namespace
when creating a parser object. This is to allow the program to pre-load
values to a namespace from conf files before parsing the command line.

=head1 SEE ALSO

Getopt::Long

Python's argparse

=head1 AUTHOR

Mytram <mytram2@gmail.com> (original author)

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by Mytram.

This is free software.

=cut

__END__
