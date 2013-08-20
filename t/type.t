use lib "../lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

# int

# float

# bool

$p->add_argument('--foo');
$p->add_argument(
    '--verbose', '-v',
    type => 'bool',
);

$ns = $p->parse_args(split(' ', '--foo 100 -v'));

diag($ns->foo);
diag($ns->verbose);

ok ($ns->foo eq 100, 'foo');
ok ($ns->verbose, 'bool true');

$p->add_argument(
    '--quiet', '-q',
    type  => 'bool',
    const => 0,
);

$ns = $p->parse_args(split(' ', '--foo 100 -v'));
diag($ns->quiet);
ok($ns->quiet, 'bool neg');

done_testing;
