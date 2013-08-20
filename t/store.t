use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;


$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument('--foo');


done_testing;
