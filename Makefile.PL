#!/usr/bin/perl
# $Id: Makefile.PL,v 1.7 2002/05/18 01:57:07 matt Exp $

use ExtUtils::MakeMaker;
use File::Find;

my @tests;
sub wanted { /\.t$/ && push @tests, $_ }
find({ wanted => \&wanted , no_chdir => 1}, '.');
@tests = sort @tests;
WriteMakefile
  ( NAME           => 'POE::Session::Cascading',

    ( ($^O eq 'MacOS')
      ? ()
      : ( AUTHOR   => 'Matt Cashner (eek+cpan@eekeek.org)',
          ABSTRACT => 'Stack-like sessions for POE',
        )
    ),

    VERSION_FROM   => 'VERSION',
    dist           => { 'COMPRESS' => 'gzip -9f',
                        'SUFFIX'   => 'gz',
                      },
    test => {
            TESTS => join " ", @tests
    }, 
    PREREQ_PM      => { 'POE' => '.19',
                        'Test::More' => '0',
                        'Carp' => '0',
                      },
  );

