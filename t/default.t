use Test::More tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument('--foo');
$p->add_argument('--required-option', required => 1, default => 10);
$p->add_argument('--optional-option', default => [ 20 ]);

$n = $p->parse_args(split(' ', '--foo 20'));

ok($n->required_option eq 10, "required default 10");
ok($n->optional_option eq 20, "optional default 20");
ok($n->foo eq 20, "foo 20");

done_testing;
