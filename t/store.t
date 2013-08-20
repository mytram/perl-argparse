use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument('--foo');

$p->add_argument('-v', action => 'store_const', const => 1);
$p->add_argument('-q', action => 'store_const', const => 0);

$line = '-v';

$ns = $p->parse_args($line);

ok ($ns->v, 'v - true');
ok ($ns->q, 'q - true');

$ns = $p->parse_args(split(' ', '-q'));

ok (!$ns->v, 'v - false');
ok (!$ns->q, 'q - false');

$p = ArgParse::ArgumentParser->new();
$p->add_argument('-v', action => 'store_true');
$p->add_argument('-q', action => 'store_false');

$line = '-v';

$ns = $p->parse_args($line);

ok ($ns->v, 'v - true');
ok ($ns->q, 'q - true');


$ns = $p->parse_args(split(' ', '-q'));

ok (!$ns->v, 'v - false');
ok (!$ns->q, 'q - false');


done_testing;
