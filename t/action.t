use lib "../lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

# store

$p->add_argument('--split', '-s', split => ',');

$n = $p->parse_args(split(' ', '-s a,b,c'));

@s = $n->split;

diag(join(' ', @s));
ok(scalar(@s) eq 3, "split");

# store_const
throws_ok (
    sub {
        $p->add_argument('--store_const', action => 'store_const');
    },
    qr/const/,
    "const missing"
);

$p->add_argument('--store-const' , action => 'store_const', const => [100, 200]);

throws_ok(
    sub { $n = $p->parse_args(split(' ', '--store-const')); },
    qr/multiple const/,
    "multiple const",
);

$p->add_argument('--store-const', action => 'store_const', const => [100]);

$n = $p->parse_args(split(' ', '--store-const'));

diag($n->store_const);

ok($n->store_const eq 100, "store_const 100");

ok($n->store_const eq 100, "store_const");

$p->add_argument('--store_true', type => 'bool', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--store_true')); },
);

ok($n->store_true, "store_true");

# store_false

$p->add_argument('--store_false', type => 'bool', const => 0, required => 0);

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

$p->add_argument('--append', action => 'append', split => ',', required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--append a,b,c --append 1')); },
);

@append = $n->append;
ok (scalar(@append) eq 2, "append split");

ok ($append[0][0] eq 'a', "append split [0][0]");
ok ($append[1][0] eq '1', "append split [0][1]");

# append_const

$p->add_argument('--append', action => 'append', split => ',', const => 100, required => 0);

lives_ok(
    sub { $n = $p->parse_args(split(' ', '--append a,b,c --append 1')); },
);

@append = $n->append;
ok (scalar(@append) eq 3, "append const split");
ok ($append[0][0] eq '100', "append const split [0][0]");


done_testing;

