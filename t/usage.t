use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use ArgParse::ArgumentParser;

my $parser = ArgParse::ArgumentParser->new;

ok($parser);

$parser->add_argument('--foo', '-f');

$parser->add_argument('--boo', type => 'Bool');

$parser->add_argument('--nboo', type => 'Bool');

$parser->add_argument('--verbose', type => 'Count');

$parser->add_argument('--email', required => 1);

$parser->add_argument('--email2', '--e2', required => 1);

$parser->add_argument('boo', required => 1);

$parser->usage();

done_testing;

__END__

my $ns = $parser->parse_args(
    '-h',
    '-f', 100,
    '--verbose', 'left', '--verbose',
    '--email', 'a@b', 'c@b', 'a@b', 1, 2,
    '--verbose', 123, '--verbose',
    '--boo', 3,
    '-e2', 'e2@e2', 9999
);

$\ = "\n";

print $ns->foo;

print $ns->nboo;

print $ns->boo;

print $ns->verbose;

print "email: ", join(', ', $ns->email);

print "argv: ", join(', ', @{$parser->{-argv}});

done_testing;

1;
