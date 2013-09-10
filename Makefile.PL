use strict;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    'ABSTRACT' => 'A Perl argument parser',
    'AUTHOR' => 'Mytram <mytram2@gmail.com>',
    'BUILD_REQUIRES' => {},
    'DISTNAME' => 'ArgParse',
    'EXE_FILES' => [],
    'LICENSE' => 'artistic',
    'NAME' => 'ArgParse::ArgumentParser',
    'PREREQ_PM' => {
        'Moo'          => '1.003',
        'Getopt::Long' => '2.38',
    },
    'VERSION_FROM' => 'lib/ArgParse/ArgumentParser.pm',
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
