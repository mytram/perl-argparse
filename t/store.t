use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use Getopt::ArgParse::Parser;

$p = Getopt::ArgParse::Parser->new();
ok($p, "new argparser");

$p->add_argument('--foo');

$p->add_argument('--vv', type => 'Bool');
$p->add_argument('-q', type => 'Bool', default => 1);

$line = '--vv';

$ns = $p->parse_args($line);

ok ($ns->vv, 'v - true');
ok ($ns->q, 'q - true');

$ns = $p->parse_args(split(' ', '-q'));

ok (!$ns->vv, 'vv - false');
ok (!$ns->q, 'q - false');

ok ($ns->no_vv, 'no_vv - true');
ok ($ns->no_q, 'no_q - true');

# positional args
$p = Getopt::ArgParse::Parser->new();

$p->add_argument('boo');

$n = $p->parse_args(split(' ', 100, 200));

ok($n->boo == 100, 'boo is 100');

done_testing;
