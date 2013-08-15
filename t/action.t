use lib "../lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

# store

# store_const
throws_ok (
    sub {
        $p->add_argument('--store_const', action => 'store_const');
    },
    qr/const/,
    "const missing"
);

$p->add_argument('--store-const', action => 'store_const', const => [100, 200]);

throws_ok(
    sub { $n = $p->parse_args(split(' ', '--store-const')); },
    qr/multiple const/,
    "multiple const",
);

$p->add_argument('--store-const', action => 'store_const', const => [100]);

$n = $p->parse_args(split(' ', '--store-const'));

diag($n->store_const);

ok($n->store_const eq 100, "store_const 100");

# store_true

ok($n->store_const eq 100, "store_const");


$p->add_argument('--store_true', action => 'store_true', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--store_true')); },
);

ok($n->store_true, "store_true");

# store_false

$p->add_argument('--store_false', action => 'store_false', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--store_false')); },
);

ok(!$n->store_false, "store_false");

# count

$p->add_argument('--count', '-c', action => 'count', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '-c -c -c')); },
);

ok($n->count eq 3, "count 3");

throws_ok(
    sub { $n = $p->parse_args(split(' ', '-ccc')); },
    qr/Getoptions/,
    "unsupported option notation",
);

# append

$p = ArgParse::ArgumentParser->new();

$p->add_argument('--append', action => 'append', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--append a --append 3 --append 1')); },
);

@append = $n->append;

ok (scalar(@append) eq 3, "3 append values");
ok ($append[0] eq 'a', "a = a");


lives_ok(
    sub { $n = $p->parse_args(split(' ', '--append b')); },
);

@append = $n->append;
ok (scalar(@append) eq 1, "3 append values");

ok ($append[0] eq 'b', "b = b");

# append_const

done_testing;

