use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();

$p->add_argument(
    '--pair', '-p',
    type  => 'Pair',
);

$p->add_argument(
    '--pairs',
    action => 'append',
    type   => 'Pair',
);

$n = $p->parse_args('--pair', 'hello=\'hello world\'', split(' ', '--pairs a=1 --pairs b=2'));

$p = $n->pair;
diag($p->{'hello'});
ok($p->{'hello'} eq '\'hello world\'', 'hello=world');

$p = $n->pairs;

ok($p->{'a'} eq '1', 'a=1');
ok($p->{'b'} eq '2', 'b=2');

done_testing;

1;
