use Test::More;
use Test::Exception;

BEGIN { use_ok ( 'ArgParse::ArgumentParser' ) };

require_ok('ArgParse::ArgumentParser');
require_ok('ArgParse::ActionStore');
require_ok('ArgParse::ActionAppend');

my $ns;

my $parser = ArgParse::ArgumentParser->new();

ok($parser, 'new parser');

$parser->add_argument(
    '-foo',
);

$parser->add_argument(
    '--boo',
    '-b',
    type     => 'bool',
    required => 1,
    dest     => 'has_boo',
);

$parser->add_argument(
    '--array',
    action   => 'append',
    required => 1,
);

throws_ok( sub {
               $ns = $parser->parse_args(split(/ /, '-foo 10 20 30 --array a --array b --array c'));
}, qr/required/, 'required option');

$ns = $parser->parse_args(split(/ /, '-foo 10 20 30 -b --array a --array b --array c'));

ok($ns->foo eq '10', 'default option');
ok($ns->has_boo, 'has boo store true');
my @values = $ns->array;
diag(join(',', @values));
ok( scalar(@values) eq 3, 'action append');

done_testing;

1;
