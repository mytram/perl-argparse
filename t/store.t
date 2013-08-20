use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument('--foo');

$p->add_argument('-v', type => 'Bool');
$p->add_argument('-q', type => 'Bool', default => 1);

$line = '-v';

$ns = $p->parse_args($line);

ok ($ns->v, 'v - true');
ok ($ns->q, 'q - true');

$ns = $p->parse_args(split(' ', '-q'));

ok (!$ns->v, 'v - false');
ok (!$ns->q, 'q - false');

done_testing;
