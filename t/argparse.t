use lib 'lib';
use lib '../lib';
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
    '--boo', '-b',
    type     => 'Bool',
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
}, qr/required/, 'required option: bool');

$ns = $parser->parse_args(split(/ /, '-foo 10 20 30 -b --array a --array b --array c'));

ok($ns->foo eq '10', 'default option');
ok($ns->has_boo, 'has boo store true');
my @values = $ns->array;
diag(join(',', @values));
ok( scalar(@values) eq 3, 'action append');

# positional args
$p = ArgParse::ArgumentParser->new();
$p->add_argument(
    'command',
);

$ns = $p->parse_args(split(/ /, 'submit hello'));

ok($ns->command eq 'submit', 'simple position');

$p->add_argument(
    'command2',
    nargs => 2,
    action => 'append',
);

$ns = $p->parse_args(split(/ /, 'submit hello1 hello2'));
$cmd2 = $ns->command2;

#use Data::Dumper;
#print Dumper($cmd2);
ok(scalar(@$cmd2) == 2, 'nargs 2');

done_testing;

1;
