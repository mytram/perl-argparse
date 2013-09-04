use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

$p = ArgParse::ArgumentParser->new();
ok($p, "new argparser");

# Miminal set up
$p->add_argument(
    '--email', '-e',
    action => 'append',
);

$line = '-e abc@perl.org -e xyz@perl.org';

$ns = $p->parse_args(split(' ', $line));

@emails = $ns->email;
diag(join ', ', @emails);
ok(scalar @emails == 2, 'append - minimal setup');

$p->add_argument('--foo');
$line = '--foo 1';
$p->namespace(undef);
$ns = $p->parse_args(split(' ', $line));
@emails = $ns->email;
diag(join ', ', @emails);
ok(scalar @emails == 0, 'append - minimal setup,not specified');

$p = ArgParse::ArgumentParser->new();
$p->add_argument('--foo');
$p->add_argument(
    '--email', '-e',
    action   => 'append',
    default  => 'mytram2@perl.org',
    required => 1,
);

$line = '--foo 1';
$ns = $p->parse_args(split(' ', $line));

@emails = $ns->email;
diag(join ', ', @emails);

ok(scalar @emails == 1, 'append - required with default');

# append default but specified
$line = '--foo 1 -e abc@perl.org';
$p->namespace(undef);
$ns = $p->parse_args(split(' ', $line));

@emails = $ns->email;
diag(join ', ', @emails);
ok(scalar @emails == 1, 'append - specified - size');
ok($emails[0] eq 'abc@perl.org', 'append - specified - element');

$emails = $ns->email;
ok(scalar(@$emails) == 1, 'append - ref - size');
ok($emails->[0] eq 'abc@perl.org', 'append - ref - element');

done_testing;
