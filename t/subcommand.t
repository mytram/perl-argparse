use Test::More;
use Test::Exception;

use lib 'lib';

use Getopt::ArgParse;
$p = Getopt::ArgParse->new_parser();

ok($p, 'new parser');

$p->add_argument(
    '--foo',
);

$sp = $p->add_subparsers(
    title       => 'Here are some subcommands',
    description => 'Use subcommands to do something',
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

$n = $p->parse_args(split(' ', '--foo 100'));

ok($n->foo == 100, 'foo is 100');

$n = $p->parse_args(split(' ', 'list -h'));

ok($n->help);
# ok ($n->foo, 'xoo is true');

done_testing;



