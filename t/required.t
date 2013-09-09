use lib 'lib';
use Test::More; # tests => 10;
use Test::Exception;

use ArgParse::ArgumentParser;
use ArgParse::Namespace;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

$p->add_argument('--required-option', required => 1);
$p->add_argument('--optional-option');

lives_ok(
    sub {$n = $p->parse_args(split(' ', '--required-option hello'));},
);

ok($n->required_option eq "hello", "required_option");
ok( !defined($n->optional_option), "optional_option is undef");

lives_ok(
    sub { $n = $p->parse_args( split(' ', '--optional-option hello') ); },
);
ok($n->required_option eq "hello", "required_option");
ok($n->optional_option eq 'hello', "optional_option is hello");

$p->namespace(ArgParse::Namespace->new()); # Clear out required-option
# multiple parsing preserves previous values
$n = $p->namespace;

$p->add_argument('--optional-option');

throws_ok(
    sub { $n = $p->parse_args( split(' ', '--optional-option hello') ); },
    qr/required/,
    "required option",
);

done_testing;
