require 5.008001;

package Getopt::ArgParse;
{
    $Getopt::ArgParse::VERSION = '0.01';
};

use strict;
use warnings;
use Carp;

use Getopt::ArgParse::Parser;

sub new_parser {
    shift;
    return Getopt::ArgParse::Parser->new(@_);
}

1;

# perldoc

=pod

=head1 NAME

Getopt::ArgParse - Parsing command line arguments with a user-friendly
interface, similar to python's argpare but with perlish extras

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use Getopt::ArgParse;

 $ap = Getopt::ArgParse->new_parser(
 	prog        => 'MyProgramName',
 	description => 'This is a program',
 );

 # Parse an option: '--foo value' or '-f value'
 $ap->add_argument('--foo', '-f', required => 1);

 # Parse a boolean: '--bool' or '-b' using a different name from
 # the option
 $ap->add_argument('--bool', '-b', type => 'Bool', dest => 'boo');

 # Parse a positonal option
 $ap->add_argument('command', required => 1);

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
 $ap->add_argument('--env', choices => [ 'dev', 'prod' ]);

 # or use case-insensitive choices
 # Override the previous option
 $ap->add_argument('--env', choices_i => [ 'dev', 'prod' ]);

 # or use a coderef
 # Override the previous option
 $ap->add_argument(
 	'--env',
 	choices => sub {
 		die "--env invalid values" if $_[0] !~ /^(dev|prod)$/i;
 	},
 );

 # subcommands
 $p->add_subparsers(title => 'subcommands');
 $list_parser = $p->add_parser('list', help => 'List directory entries');
 $list_parser->add_arguments(
   [
     '--verbose', '-v',
      type => 'Count',
      help => 'Verbosity',
   ],
   [
     '--depth',
      help => 'depth',
   ],
 );

 #

 

=head1 DESCRIPTIOIN

Getopt::ArgParse, Getopt::ArgParse::Parser and related classes
together aim to provide user-friendly interfaces for writing
command-line interfaces. A user should be able to use it without
looking up the document most of the time. It allows applications to
define argument specifications and it will parse them out of @AGRV by
default or a command line if provided. It implements both optional
arguments, using Getopt::Long for parsing, and positional
arguments. The class also generates help and usage messages.

The parser has a namespace property, which is an object of
ArgParser::Namespace. The parsed argument values are stored in this
namespace property. Moreover, the values are stored accumulatively
when parse_args() is called multiple times.

Though inspired by Python's argparse and names and ideas are borrowed
from it, there is a lot of difference from the Python one.

Getopt::ArgParse::Parser is a Moo class.

=head2 METHODS

=head3 Constructor

Getopt::ArgParse->new_parser( ...) or Getopt::ArgParse::Parser->new( ... )

The former calls Getopt::ArgParser::Parser->new to create a parser
object.  The parser constructor accepts the following parameters.

=over 8

=item * prog

The program's name. Default $0.

=item * description

A description of the program.

=item * namespace

An object of Getopt::ArgParse::Namespace. An empty namespace is created if
not provided. The parsed values are stored in it, and they can be
refered to by their argument names as the namespace's properties,
e.g. $parser->namespace->boo. See also Getopt::ArgParse::Namespace

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

=item * choices or choices_i

choices specifies a list of the allowable values for the argument or a
subroutine that validates input values.

choices_i specifies a list of the allowable values for the argument,
but case insenstive, and it doesn't allow to use a subroutine for
validation.

Either choices or chioces_i can be present or completely omitted, but
not both at the same time.

=item * default

The value produced if the argument is absent from the command line.

Only one value is allowed for scalar argument types: Scalar, Count, and Bool.

=item * required

Whether or not the command-line option may be omitted (optionals only).

=item * help

A brief description of what the argument does.

=item * metavar

A name for the argument in usage messages.

=item * groups

Specify which option groups the current option belongs to. Usage
messages will be grouped together.

By default, an option is put under an unnamed group.

=cut

=item * nargs - Positional option only

This only instructs how many arguments the parser consumes. The
program still needs to specify the right type to achieve the desired
result.

=over 8

=item * n

1 if not specified

=item * ?

1 or 0

=item * +

1 or more

=item * *

0 or many. This will consume the rest of arguments.

=back

=back

=head3 parse_args( ... )

This object method accepts a list of arguments or @ARGV if
unspecified, parses them for values, and stores the values in the
namespace object.

It displays a generated usage message if both @ARGV and argument list
are empty.

=head4 Parsing for Positional Arguments

The parsing for positional arguments takes place after that for
optional arguments. It will consume what's still left in the command
line.

=head4 The namespace object is accumulatively poplulated

If parse_args() is called multiple times to parse a number of command
lines, the same namespace object is accumulatively populated.  For
Scalar and Bool options, this means the previous value will be
overwrittend. For Pair and Array options, values will be appended. And
for a Count option, it will add on top of the previous value.

In face, the program can choose to pass a already populated namespace
when creating a parser object. This is to allow the program to pre-load
values to a namespace from conf files before parsing the command line.

=head3 argv()

Call this after parse_args() is invoked to get the unconsumed
arguments.

=head2 Usage Messages and Related Methods

Call usage() to retrieve a full usage message or call group_usage() to
customize usage messages at a finer level.

=head3 group_usage( [$group] )

Return the usage messages for the $group group. If $group is not
given, it returns the usage messages for the default group.


=head3

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

