use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument(
    '--e',
    action => 'append',
    split => ',',
);

$n = $p->parse_args(split(' ', '--e a,b,c'));

@e = $n->e;

ok (scalar @e eq 3, "split count");
ok (join(',', @e) eq 'a,b,c', "split value");


$p->add_argument(
    '--pairs',
    action => 'append',
    split => ',',
    type   => 'Pair',
);

$n = $p->parse_args(split(' ', '--pairs a=1,b=2,c=3'));

$p = $n->pairs;

ok($p->{'a'} eq '1', 'a=1');
ok($p->{'b'} eq '2', 'b=2');
ok($p->{'c'} eq '3', 'c=3');

done_testing;

1;



