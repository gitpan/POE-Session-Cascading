# Test session creation

use Test::More tests => 13;
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
            name => 'test',
            events => [
                'state1' => sub { warn 'state1'; },
                'state2' => sub { warn 'state2'; },
                'state3' => sub { my %args = @_; warn 'state3'; $args{SESSION}->stop; },
            ],
          );

ok($sess, 'Session object creation');
is($sess->{name},'test', 'Session name storage');
is(ref $sess->{stack}, 'ARRAY', 'Session stack storage');
is(ref $sess->{info}, 'HASH', 'Session stack info storage');

$POE::Kernel::poe_kernel->catch('session_alloc');
eval { POE::Session::Cascading->new(name => 'methodtest', events => [ 'state1' => sub {} ] ); };
like($@, qr/Caught session_alloc/, '$kernel->session_alloc gets called appropriately');
$POE::Kernel::poe_kernel->catch(undef);

eval { POE::Session::Cascading->new() };
like($@, qr/No arguments passed to new\(\). Cannot continue./, 'new() failure with no args');

eval { POE::Session::Cascading->new('pants'); };
like($@, qr/Odd number of arguments passed to new\(\). Cannot continue./, "new() failure with an odd number of arguments");

eval { POE::Session::Cascading->new( events => [] ); };
like($@, qr/Argument 'name' not passed to new\(\). Cannot continue./, 'new() failure without "name" argument');

eval { POE::Session::Cascading->new('name' => 'emptyargs' ); };
like($@, qr/Argument 'events' not passed to new\(\). Cannot continue./, 'new() failure without "events" argument.');

eval { POE::Session::Cascading->new( 'name' => 'eventsargs', events => {} ); };
like($@, qr/Argument 'events' not an array reference in new\(\). Cannot continue./, 'new() failure when "events" argument not an array reference');

eval { POE::Session::Cascading->new( 'name' => 'test', events => [ 'state1' => sub { 'pants' } ] ); };
like($@, qr/There is already a session by the name of 'test'. Cannot continue./, 'new() failure on duplicate name');

eval { POE::Session::Cascading->new( 'name' => 'codreftest', events => [ 'state1' => 'state1' ] ); };
like($@, qr/Event 'state1' not a code reference. Skipping./, 'new() warning when event is not a code reference');


