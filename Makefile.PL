#!/usr/bin/perl
# $Id: Makefile.PL 328 2004-06-17 15:29:39Z sungo $

use ExtUtils::MakeMaker;
use File::Find;

my @tests;
sub wanted { /\.t$/ && push @tests, $_ }
find({ wanted => \&wanted , no_chdir => 1}, '.');
@tests = sort @tests;

WriteMakefile( 
    NAME            => 'POE::Session::Cascading',
    AUTHOR          => 'Matt Cashner (sungo@pobox.com)',
    ABSTRACT        => 'Stack-like sessions for POE',

    VERSION_FROM    => 'lib/POE/Session/Cascading.pm',
    dist            => { 
        'COMPRESS' => 'gzip -9f',
        'SUFFIX'   => 'gz',
        'PREOP'     => 'svn log > ${DISTVNAME}/Changes',
    },
    test => {
        TESTS => join " ", @tests
    }, 
    PREREQ_PM      => { 
        'POE' => '.19',
        'Test::More' => '0',
        'Carp' => '0',
    },
  );

