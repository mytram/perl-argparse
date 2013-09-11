use lib "lib";
use Test::More;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument(
    '--choice',
    choices => [ 'a', 'b', 'c' ],
);

throws_ok(
    sub { $n = $p->parse_args(split(' ', '--choice hello')); },
    qr/not in/,
    'choice error: not in choices - arrayref'
);

$p->add_argument(
    '--choice1',
    choices => sub {
        die "not in ['a', 'b', 'c']" unless $_[0] =~ /^(a|b|c)$/i;
    }
);

throws_ok(
    sub { $n = $p->parse_args(split(' ', '--choice1 hello')); },
    qr/not in/,
    'choice error: not in choices - coderef'
);

$n = $p->parse_args(split(' ', '--choice1 A --choice a'));

ok($n->choice eq 'a', 'choice ok - fixed value a');

ok($n->choice1 eq 'A', 'choice ok - case insensative A');

done_testing;
