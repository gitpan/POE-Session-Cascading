
use inc::Module::Install;
use File::Find;

my @tests;
sub wanted { /\.t$/ && push @tests, $_ }
find({ wanted => \&wanted , no_chdir => 1}, '.');
my $tests = join " ", sort @tests;


name            ('POE-Session-Cascading');
author          ('Matt Cashner (sungo@pobox.com)');
version_from    ('VERSION');
license         ('bsd');

requires        ('POE' => '0.19');
requires        ('Carp');
build_requires  ('Test::More');

tests           ($tests);

WriteAll();
