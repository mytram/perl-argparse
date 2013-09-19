use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;

use Getopt::ArgParse::Parser;

my $parser = Getopt::ArgParse::Parser->new(
    prog => 'usage.t',
    description => 'This is the suite that contains usage message test cases',
);

ok($parser);

$parser->add_group_description(
    submit => 'This is submit subcommand' x 6,
);

$parser->add_argument('--foo', '-f', groups => 'submit');

$parser->add_argument('--boo', type => 'Bool');

$parser->add_argument('--nboo', type => 'Bool');

throws_ok (
    sub { $parser->add_argument('--verbose', type => 'Count'); },
    qr/not allow/,
    'not allow to override',
);

$parser->add_argument('--verbose', type => 'Count', groups => 'commit', reset => 1);
$parser->add_argument('--email', required => 1);

$parser->add_argument('--email2', '--e2', required => 1);

throws_ok(
  sub {  $parser->add_argument('boo', required => 1); },
  qr/used by an optional/,
  'dest=boo is used',
);

$parser->add_argument('boo', required => 1, groups => 'post', dest => 'boo_post');

$parser->add_argument('boo2', type => 'Pair', required => 1, default => { a => 1, 3 => 90 });

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
