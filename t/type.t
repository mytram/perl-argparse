use lib "../lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

# not supported yet
$p->add_argument('--type-hash', type => 'pair');

$n = $p->parse_args(split(' ', '--type-hash a=b'));

$v = $n->type_hash;

use Data::Dumper;

print Dumper($n);

ok ($v->{a} eq 'b', 'hash a=b');

done_testing;
