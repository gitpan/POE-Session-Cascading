# Test the ability to have multiple sesesions 

# should be 15 tests that branch like so:
# mt1 - st1
#    mt2 - st1
#        mt1 - st3
#            mt2 - st2
#            mt2 - st3
#                mt1 - st4
#            mt2 - st4
#        mt1 - st4
#mt1 - st2
#mt1 - st3
#    mt2 - st2
#    mt2 - st3
#        mt1 - st4
#    mt2 - st4
#mt1 - st4


use Test::More tests => 15;
use warnings;
use strict;

local $SIG{__WARN__} = sub { $@ = shift; die $@; };

BEGIN { use_ok('POE::Session::Cascading'); }

use POE;

my $sess1 = POE::Session::Cascading->new(
    name => 'multitest1',
    events => [
        'state1' => sub { pass('state1 in multitest1'); $poe_kernel->post('multitest2','state1'); },
        'state2' => sub { pass('state2 in multitest1'); },
        'state3' => sub { pass('state3 in multitest1'); $poe_kernel->post('multitest2','state2'); },
        'state4' => sub { my %args = @_; pass('state4 in multitest1');  $args{SESSION}->stop },
    ]
);

my $sess2 = POE::Session::Cascading->new(
    name => 'multitest2',
    events => [
        'state1' => sub { pass('state1 in multitest2'); $poe_kernel->post('multitest1','state3'); },
        'state2' => sub { pass('state2 in multitest2'); },
        'state3' => sub { pass('state3 in multitest2'); $poe_kernel->post('multitest1','state4'); },
        'state4' => sub { my %args = @_; pass('state4 in multitest2'); $args{SESSION}->stop },
    ]
);

POE::Session->create(
    inline_states => {
        _start => sub { $_[KERNEL]->post('multitest1','state1'); $_[KERNEL]->delay('nuke',3); },
        nuke => sub { $_[KERNEL]->session_free($sess1); $_[KERNEL]->session_free($sess2);},
    }
);

$poe_kernel->run();
