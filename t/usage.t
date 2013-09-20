use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use Getopt::ArgParse::Parser;

my $parser = Getopt::ArgParse::Parser->new(
    prog => 'usage.t',
    description => 'This is the suite that contains usage message test cases',
);

ok($parser);

$parser->add_argument('--foo', '-f');

$parser->add_argument('--boo', type => 'Bool');

$parser->add_argument('--nboo', type => 'Bool');

$parser->add_argument('--verbose', '-v', type => 'Bool');

throws_ok (
    sub { $parser->add_argument('--verbose', type => 'Count'); },
    qr/not allow/,
    'not allow to override',
);

$parser->add_argument('--verbose', type => 'Count', reset => 1);
$parser->add_argument('--email', required => 1);

$parser->add_argument('--email2', '--e2', required => 1);

throws_ok(
  sub {  $parser->add_argument('boo', required => 1); },
  qr/used by an optional/,
  'dest=boo is used',
);

$parser->add_argument('boo', required => 1, dest => 'boo_post');

$parser->add_argument('boo2', type => 'Pair', required => 1, default => { a => 1, 3 => 90 });


# subcommands

$parser->add_subparsers(title => 'Some subcommands', description => 'there are some subcommands');

$sp = $parser->add_parser(
    'list',
    aliases => [qw(ls)],
    help => 'this is the list subcommand message',
);

$sp->add_argument(
    '--foo', '-f',
    help => 'subcommand foo',
);

$parser->print_usage();

print STDERR $_, "\n" for @{ $parser->format_command_usage('ls') };

done_testing;

__END__

my $ns = $parser->parse_args(
    '-h',
    '-f', 100,
    '--verbose', 'left', '--verbose',
    '--email', 'a@b', 'c@b', 'a@b', 1, 2,
    '--verbose', 123, '--verbose',
    '--boo', 3,
    '-e2', 'e2@e2', 9999
);

$\ = "\n";

print $ns->foo;

print $ns->nboo;

print $ns->boo;

print $ns->verbose;

print "email: ", join(', ', $ns->email);

print "argv: ", join(', ', @{$parser->{-argv}});

done_testing;

1;
