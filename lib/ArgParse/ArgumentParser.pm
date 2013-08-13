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

    while( my ($key, $value) = each %$args ) {
        $self->{"-$key"} = $value;
    }

    $self->add_argument(
        '--help', '-h',
        action => 'store_true',
        help   => 'show this help message and exit',
    );
}

sub prog           { $_[0]->{'-prog'} }
sub description    { $_[0]->{'-description'} }
sub parser_configs { wantarray ? @{ $_[0]->{'-parser_configs'} } : $_[0]->{'-parser_configs'} }

sub add_arguments {
    my $self = shift;

    $self->add_argument($_) for @_;
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

    return unless @_;

    my $name;

    my @flags = ();

  FLAG:
    while (my $flag = shift @_) {
        if (substr($flag, 0, 1) eq '-') {
            $flag =~ s/^-+//; # default name
            push @flags, $flag;
        } else {
            unshift @_, $flag;
            last FLAG;
        }
    }

    if ( @flags ) {
        $name = $flags[0];
    } else {
        # positional argument
        $name = shift @_;
    }

    croak "Must provide argument name" unless $name;

    if (@_ % 2 ) {
        croak "Incorrect arguments";
    }

    my $args = { @_ };

    my $action_name = $args->{action} || 'store';

    my $action = $Action2ClassMap{$action_name}
        if exists $Action2ClassMap{$action_name};

    {
        local $SIG{__DIE__};

        eval "require $action";

        croak $@ if $@;
    };

    my $const = $args->{const};

    if ($action_name =~ /_const!/) {
        croak 'const must be provided for store_const'
            unless defined $const;
    } else {
        # throw away your const - warning?
        $const = undef;
    }

    # throw away your const
    $const = CONST_TRUE() if $action_name eq 'store_true';
    $const = CONST_FALSE() if $action_name eq 'store_false';

    # nargs
    my $nargs = $args->{nargs};

    if ( ! defined $nargs ) {
        $nargs = $action->nargs if $action->can('nargs');
    }

    $nargs = undef if defined($nargs) && "$nargs" eq '1';

    # type

    my $type_name = $args->{type} || '';
    my $type = $Type2ConstMap{$type_name};

    my $dest = $args->{dest} || $name;

    croak "Must provide a name or a dest" unless $dest;

    $dest =~ s/-/_/g;

    my $spec = {
        name     => $name,
        flags    => \@flags,
        action   => $action,
        nargs    => $nargs,
        const    => $const,
        required => $args->{required},
        type     => $type,
        default  => (ref($args->{default}) eq 'ARRAY' ? $args->{default} : $args->{default}),
        dest     => $dest,
        choices  => $args->{choices} || [],
        help     => $args->{help} || '',
    };

    if (@flags) {
        $self->{-option_specs}{$spec->{dest}} = $spec;
        # push @ { $self->{-option_specs} } }, $spec;
    } else {
        push @ { $self->{-position_specs} }, $spec;
    }

    return $self;
}

sub _get_option_spec {
    my $class = shift;
    my $spec  = shift;

    my $name = join('|', @{ $spec->{flags} });
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

sub parse_args {
    my $self = shift;

    my @saved_argv = @ARGV;

    my @argv = scalar(@_) ? @_ : @ARGV;

    unless (@argv) {
        $self->usage();
        exit(0);
    }

    my $namespace = ArgParse::Namespace->new();

    Getopt::Long::Configure( $self->parser_configs );

    my $options   = {};
    my $dest2spec = {};

    for my $spec ( values %{ $self->{-option_specs} } ) {
        my @values;
        if ($spec->{default}) {
            push @values,
                (ref($spec->{default}) ? @{$spec->{default}} : $spec->{default});
        }
        $dest2spec->{$spec->{dest}} = $self->_get_option_spec($spec);
        $options->{ $dest2spec->{$spec->{dest}} } = \@values;
    }

    my $result = GetOptionsFromArray( \@argv, %$options );

    if (!$result) {
        die "Getoptions error";
    }

    # required
    for my $spec ( values %{ $self->{-option_specs} } ) {
        croak sprintf('%s is required', $spec->{dest}),
            if $spec->{required} && ! scalar(@{$options->{ $dest2spec->{$spec->{dest}} }});
    }

    # choices
    for my $spec ( values %{ $self->{-option_specs} } ) {
        next unless scalar(@{ $spec->{choices} });
    }

    # action
    for my $spec ( values %{ $self->{-option_specs} } ) {
        my $action = $spec->{action};

        $action->apply($spec, $namespace, $options->{ $dest2spec->{$spec->{dest}} }, $spec->{name});
    }

    # positional arguments
    $self->{-argv} = \@argv;

    Getopt::Long::Configure('default');

    if ($namespace->get_attr('help')) {
        $self->usage();
        exit(0);
    }

    return $namespace;
}

sub usage {
    my $self = shift;

    my @usage;

    push @usage, sprintf('usage: %s', $self->prog);

    push @usage, "\n";

    push @usage, 'optional arguments:';

    for my $spec (values %{$self->{-option_specs}}) {
       push @usage, sprintf('  %s %s        %s',
                             join(', ', (map { "-$_" } @{$spec->{flags}})),
                             ($spec->{metavar} || uc($spec->{dest})),
                             $spec->{help}
       );
    }

    print STDERR join("\n", @usage);
}


1;

