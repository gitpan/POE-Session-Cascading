# Test state invocation

use Test::More tests => 10;
use warnings;
use strict;

local $SIG{__WARN__} = sub { $@ = shift; die $@; };

BEGIN { 
    use_ok('POE::Session::Cascading'); 
    use lib qw(t/);
    use MockObject;
    $POE::Kernel::poe_kernel = MockObject->new();
}

my $sess = POE::Session::Cascading->new(
                name => 'test2',
                events => [
                    'state1' => sub { my %args = @_; warn "state1" if shift @{$args{ARGS}} == 1; },
                    'state2' => sub { my %args = @_; warn 'state2' if shift @{$args{ARGS}} == 2; $args{SESSION}->stop; },
                ]
           );


eval { POE::Session::Cascading::_invoke_state(); };
like($@,qr/Assertion \(Object integrity\) failed!/, '_invoke_state() asserts that the session object must exist');

eval { POE::Session::Cascading::_invoke_state($sess,$sess); };
like($@, qr/Assertion \(State name\) failed!/, '_invoke_state() asserts that the state name must be passed in');

$POE::Kernel::poe_kernel->catch('alias_set');
eval { POE::Session::Cascading::_invoke_state($sess,$sess,'_start') };
like($@, qr/Caught alias_set/, '$poe_kernel->alias_set call in _start');

$POE::Kernel::poe_kernel->catch('delay');
eval { POE::Session::Cascading::_invoke_state($sess,$sess,'_start') };
like($@, qr/Caught delay/, '$poe_kernel->delay call in _start');

eval { POE::Session::Cascading::_invoke_state($sess,$sess,'_ping') };
like($@, qr/Caught delay/, '$poe_kernel->delay call in _ping');

$POE::Kernel::poe_kernel->catch('post');
eval { POE::Session::Cascading::_invoke_state($sess,$sess,'state1'); };
like($@, qr/Caught post/, '$poe_kernel->post when calling a known state');

$POE::Kernel::poe_kernel->catch(undef);
eval { $sess->step(0,1) };
like($@, qr/state1/, 'step() firing of state1');

eval { $sess->step(1,2) };
like($@, qr/state2/, 'step() firing of state2');

eval { POE::Session::Cascading::_invoke_state($sess,$sess,'_stop'); }; 
ok(!defined $POE::Session::Cascading::STACK{'test2'},'deletion of stack in _stop');


