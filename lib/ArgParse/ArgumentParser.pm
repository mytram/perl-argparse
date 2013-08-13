require 5.008001;

package ArgParse::ArgumentParser;
{
    $ARgParse::ArgumentParser::VERSION = '0.01';
}

use Carp;
use warnings;
use strict;
use Data::Dumper;

use ArgParse::Namespace;

use Getopt::Long qw(GetOptionsFromArray);

use constant {
    TYPE_UNDEF   => 0,
    TYPE_STRING  => 1,
    TYPE_INTEGER => 2,
    TYPE_FLOAT   => 3,
    TYPE_PAIR	 => 4, # key=value pair

    CONST_TRUE         => 1,
    CONST_FALSE        => 0,
};

my %Action2ClassMap = (
	'store'        => 'ArgParse::ActionStore',
    'store_const'  => 'ArgParse::ActionStore',
    'store_true'   => 'ArgParse::ActionStore',
    'store_false'  => 'ArgParse::ActionStore',
    'append'       => 'ArgParse::ActionAppend',
    'append_const' => 'ArgParse::ActionAppend',
    'count'        => 'ArgParse::ActionCount',
    'help'         => 'ArgParse::ActionHelp',
    'version'      => 'ArgParse::ActionVersion',
);

my %Type2ConstMap = (
    ''     => TYPE_UNDEF(),
    'int'  => TYPE_INTEGER(),
    'str'  => TYPE_STRING(),
    'pair' => TYPE_PAIR(),
);

#
sub new {
    my $class = shift;
    my $real_class = ref $class || $class;

    my $args = { @_ };

    my $self = {};

    bless $self, $real_class;

    $self->init($args);

    return $self;
}

sub init {
    my $self = shift;
    my $args = shift;

    $self->{'-prog'}           = delete $args->{'prog'} || $0;
    $self->{'-description'}    = delete $args->{'description'} || '';
    $self->{'-parser_configs'} = delete $args->{'parser_configs'}  || [];
    $self->{'-option_position'} = 0;

    while( my ($key, $value) = each %$args ) {
        $self->{"-$key"} = $value;
    }

    $self->add_argument(
        '--help', '-h',
        action => 'store_true',
        help   => 'show this help message and exit',
    );

    if (my $p = $args->{parent}) {
        $self->add_arguments( @ { $p->{-pristine_add_arguments} || [] } );
    }
}

sub prog           { $_[0]->{'-prog'} }
sub description    { $_[0]->{'-description'} }
sub parser_configs { wantarray ? @{ $_[0]->{'-parser_configs'} } : $_[0]->{'-parser_configs'} }

sub add_arguments {
    my $self = shift;

    $self->add_argument(@$_) for @_;
}

#
# add_argument()
#
#    name or flags - Either a name or a list of option strings, e.g. foo or -f, --foo.
#    action        - The basic type of action to be taken when this argument is encountered at the command line.
#    nargs         - The number of command-line arguments that should be consumed.
#    const         - A constant value required by some action and nargs selections.
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

    ################
    # name or flags
    ################
    my ($name, @flags);

    #
  FLAG:
    while (my $flag = shift @_) {
        if (substr($flag, 0, 1) eq '-') {
            push @flags, $flag;
        } else {
            unshift @_, $flag;
            last FLAG;
        }
    }

    # It's a positional argument spec if there are no flags
    $name = @flags ? $flags[0] : shift(@_);
    $name =~ s/^-+//g;

    croak "Must provide at least one non-empty argument name" unless $name;

    croak "Incorrect arguments" if @_ % 2;

    my $args = { @_ };

    ################
    # action
    ################
    my $action_name = $args->{action} || 'store';

    my $action = $Action2ClassMap{$action_name}
        if exists $Action2ClassMap{$action_name};

    {
        local $SIG{__WARN__};
        local $SIG{__DIE__};

        eval "require $action";

        croak "Cannot find the module for action $action" if $@;
    };

    ################
    # nargs
    ################
    my $nargs = $args->{nargs};

    if (! defined $nargs) {
        $nargs = $action->nargs if $action->can('nargs');
    }

    # 1 is the same as undef
    $nargs = undef if defined($nargs) && "$nargs" eq '1';

    ################
    # const
    ################
    my $const = $args->{const};

    if ($action_name =~ /const!/i) {
        croak "const must be provided for $action_name"
            unless defined $const;
    } else {
        # throw away your const - warning?
        $const = undef;
    }

    # This is a hack. Ideally the parser should be independent of the
    # action
    $const = CONST_TRUE() if $action_name eq 'store_true';
    $const = CONST_FALSE() if $action_name eq 'store_false';

    ################
    # type
    ################
    my $type_name = $args->{type} || '';
    my $type = $Type2ConstMap{$type_name};

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
    my $choices = $args->{choices};
    if ($choices && ref($choices) eq 'ARRAY') {
        croak "Must provice choices in an array ref";
    }

    ################
    # required
    ################
    my $required = $args->{required} || '';

    ################
    # help
    ################
    # $args->{help}

    ################
    # metavar
    ################
    my $metavar = $args->{metavar} || uc($name);
    $metavar = '' if (defined($nargs) && "$nargs" eq "0")
        || $action_name eq 'store_true'
        || $action_name eq 'store_false'
        || $action_name eq 'count';

    ################
    # dest
    ################
    my $dest = $args->{dest} || $name;
    $dest =~ s/-/_/g; # option-name becomes option_name

    # never modify existing ones so that the parent's structure will
    # not be modified
    my $spec = {
        name     => $name,
        flags    => \@flags,
        action   => $action,
        nargs    => $nargs,
        const    => $const,
        required => $args->{required},
        type     => $type,
        default  => $default || [],
        choices  => $choices,
        dest     => $dest,
        metavar  => $metavar,
        help     => $args->{help} || '',
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

sub parse_args {
    my $self = shift;

    my @saved_argv = @ARGV;

    my @argv = scalar(@_) ? @_ : @ARGV;

    unless (@argv) {
        my $usage = $self->usage();
        print STDERR join("\n", @$usage);
        exit(0);
    }

    my $namespace = ArgParse::Namespace->new();

    Getopt::Long::Configure( $self->parser_configs );

    my $options   = {};
    my $dest2spec = {};

    my @option_specs = sort {
        $a->{position} <=> $b->{position}
    } values %{$self->{-option_specs}};

    for my $spec ( @option_specs ) {
        my @values =  @{$spec->{default}};
        $dest2spec->{$spec->{dest}} = $self->_get_option_spec($spec);
        $options->{ $dest2spec->{$spec->{dest}} } = \@values;
    }

    my $result = GetOptionsFromArray( \@argv, %$options );

    if (!$result) {
        die "Getoptions error";
    }

    # required
    for my $spec ( @option_specs ) {
        croak sprintf('%s is required', $spec->{dest}),
            if $spec->{required} && ! scalar(@{$options->{ $dest2spec->{$spec->{dest}} }});
    }

    # choices
    for my $spec ( @option_specs ) {
        next unless scalar(@{ $spec->{choices} || [] });
        for my $v (@{$options->{ $dest2spec->{$spec->{dest}} }}) {
            unless (grep {
                (!defined($v) && !defined($_)) || $v eq $_
            } @{ $spec->{choices} } ) {
                croak sprintf(
                    "option %s value %s not in [ %s ]",
                    $spec->{dest},
                    $v,
                    join(', ', @{$spec->{choices}}),
                );
            }
        }
    }

    # action
    for my $spec ( @option_specs) {
        my $action = $spec->{action};

        $action->apply($spec, $namespace, $options->{ $dest2spec->{$spec->{dest}} }, $spec->{name});
    }

    # positional arguments
    $self->{-argv} = \@argv;

    Getopt::Long::Configure('default');

    if ($namespace->get_attr('help')) {
        my $usage = $self->usage();
        print STDERR join("\n", @$usage);
        exit(0);
    }

    return $namespace;
}


sub usage {
    my $self = shift;

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
    push @usage, $self->description if $self->description;

    push @usage, "\n";

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
    my $format = "  %${max}s    %s";
    for my $ih (@item_help) {
       push @usage, sprintf($format, @$ih)
    }

    push @usage, "\n";

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
    } else {
        # pass
        # should never be here
    }

    my $repeat = '';

    if (defined $spec->{nargs}) {
        my $nargs = $spec->{nargs};
        $type = 's' unless $type;
        $optional_flag = '='; # requiring options

        if ($nargs eq '?') {
            $repeat = '{0,1}';
        } elsif ($nargs eq '*') {
            $repeat = '{,}';
        } elsif ($nargs eq '+') {
            $repeat = '{,}';
        } elsif ( "$nargs" eq '0' ) {
            $type          = '';
            $optional_flag = '+';
            $desttype      = '';
        } elsif ($nargs =~ /^\d$/) {
            $repeat = "{$nargs}";
        } else {
            croak "incorrect -nargs: $nargs";
        }

        $desttype = '';
    }

    return join('', $name, $optional_flag, $type, $repeat, $desttype);
}

1;
