use lib "lib";
use Test::More; # tests => 4;
use Test::Exception;
use Carp qw(croak);

use Getopt::ArgParse;

my $ap = Getopt::ArgParse->new_parser(
    prog        => 'foto',
    description => 'Foto is a photo/media manager',
);

$ap->add_subparsers(title => 'Subcommands');

__PACKAGE__->add_add_argparser(
    $ap
);

my $ns;

throws_ok {
    $ns = $ap->parse_args(split ' ', 'add --root .');
} qr/Option src is required/, 'required option is missing';

ok(!$ns, "no namespace");

throws_ok {
    $ns = $ap->parse_args(split ' ', 'add --root . --dry-run --number');
} qr/Option number requires an argument/, 'required argument';

ok(!$ns, "no namespace");

done_testing;

sub add_add_argparser {
    my $class = shift;
    my $parent = shift;

    croak 'Must provide a global parser' if !$parent;

    my $add_ap = $parent->add_parser(
        'add',
        help => 'Add photos to repo',
        #
    );

    $add_ap->add_args(
        [
            '--root', '-t',
            help => 'The repo root',
            required => 1,
        ],
        [
            '--src', '-s',
            required => 1,
            help => 'The path to the file to be added. Or the directory if --recursive is specified',
        ],
        [
            '--action',
            help => 'Move or copy',
        ],
        [
            '--recursive', '-R',
            type => 'Bool',
            help => 'Recursively added files',
        ],
        [
            '--location', '-l',
            help => 'Force to add this location in repo',
        ],
        [
            '--number', '-n',
            help => 'stop at --number objects',
        ],
        [
            '--trash',
            help => 'Move duplicated objects to this folder',
        ],
        [
            '--unsorted',
            help => 'Move unsorted objects to this folder',
        ],
        [
            '--dry-run',
            type => 'Bool',
            help => 'Dry run',
        ],
    );

    return $parent;
}


