use strict;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    'ABSTRACT'       => 'A Perl argument parser',
    'AUTHOR'         => 'Mytram <mytram2@gmail.com>',
    'BUILD_REQUIRES' => {},
    'DISTNAME'       => 'Getopt-ArgParse',
    'EXE_FILES'      => [],
    'LICENSE'        => 'perl',
    'NAME'           => 'Getopt-ArgParse',
    MIN_PERL_VERSION => '5.008',
    'PREREQ_PM' => {
        'Moo'          => '1.003',
        'Getopt::Long' => '2.38',
    },
    'VERSION_FROM' => 'lib/Getopt/ArgParse.pm',
    'ABSTRACT_FROM' => 'lib/Getopt/ArgParse.pm',
    'test' => {
        'TESTS' => 't/*.t'
    },
    META_MERGE => {
resources => {
repository => 'https://github.com/mytram/perl-argparse',
},
   },
);

WriteMakefile(%WriteMakefileArgs);
