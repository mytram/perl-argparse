use Test::More;
use Test::Exception;

use lib 'lib';

use Getopt::ArgParse;
$p = Getopt::ArgParse->new_parser();

ok($p, 'new parser');


throws_ok(
    sub { $p->add_subparsers( 'parser', ); },
    qr /incorrect number of arguments/,
    'incorrect number of args',
);

throws_ok(
    sub { $p->add_subparsers( something => 'parser', something2 => 'parser'); },
    qr /unknown parameters: something/,
    'unknown parameters',
);

lives_ok(
    sub { $p->add_subparsers(); },
);

throws_ok(
    sub { $p->add_subparsers(); },
    qr/subparsers already added/,
    'subparsers already added',
);


$p = Getopt::ArgParse->new_parser();

$p->add_argument(
    '--foo',
);

throws_ok(
    sub { $pp = $p->add_parser('list') },
    qr /add_subparsers\(\) is not called/,
    'add_subparsers is not called'
);

$sp = $p->add_subparsers(
    title       => 'Here are some subcommands',
    description => 'Use subcommands to do something',
);

throws_ok(
    sub { $pp = $p->add_parser() },
    qr /subcommand is empty/,
    'subcommand is empty',
);

throws_ok(
    sub { $pp = $p->add_parser(listx => 'add listx') },
    qr/incorrect number of arg/,
    'incorrect number of args',
);

throws_ok(
    sub { $p->add_parser( 'listx', something => 'parser', something2 => 'parser'); },
    qr /unknown parameters: something/,
    'unknown parameters',
);

$listx_p = $sp->add_parser(
    'listx',
);

throws_ok(
    sub { $pp = $p->add_parser('listx') },
    qr /subcommand listx already defined/,
    'subcommand listx already defined',
);


$list_p = $sp->add_parser(
    'list',
    aliases => [ qw(ls) ],
    help => 'This is the list subcommand',
);

$list_p->add_argument(
    '--foo', '-x',
    type => 'Bool',
    help => 'this is list foo',
);

$list_p->add_argument(
    '--boo', '-b',
    type => 'Bool',
    help => 'this is list boo',
);

# parse for the top command
$n = $p->parse_args(split(' ', '--foo 100'));
ok($n->foo == 100, 'foo is 100');
throws_ok(
    sub { $n->boo },
    qr /unknown option: boo/,
    'unknown option',
);

# $n = $p->parse_args(split(' ', '-h list'));
# ok($n->help);

throws_ok(
    sub {
        $n = $p->parse_args(split(' ', 'list2 --foo'));
    },
   qr/list2 is not a .* command. See help/,
   'list2 is not a command',
);

lives_ok(
    sub {
        $n = $p->parse_args(split(' ', 'list --boo -foo'));
    },
);

ok($n->foo, "list's foo is true");
ok($n->boo, "list's boo is true");

# ok ($n->foo, 'xoo is true');

done_testing;

