# Test session creation

use Test::More qw(no_plan);
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

my $pos1 = $sess->{info}->{'state1'};
my $pos2 = $sess->{info}->{'state2'};

eval { $sess->swap('state1','state2'); };
is($@, '', 'swap() success');
eval { $sess->{stack}->[0]->() };
like($@, qr/state2/, 'proper state 1 is called after swap');
eval { $sess->{stack}->[1]->() };
like($@, qr/state1/, 'proper state 2 is called after swap');

is($sess->{info}->{'state1'}, $pos2, 'internal pointer to state1 points to the new location');
is($sess->{info}->{'state2'}, $pos1, 'internal pointer to state2 points to the new location');

eval { POE::Session::Cascading::swap('foo','bar'); };
like($@, qr/Assertion \(Object integrity\) failed/, 'assert failure if object integrity is violated');

my $bad_sess = bless { }, 'POE::Session::Cascading';
eval { POE::Session::Cascading::swap($bad_sess,'foo','bar'); };
like($@,qr/Assertion \(Stash integrity\) failed/, 'assert failure if stash integrity is violated');

$bad_sess->{info} = 'pants';
eval { POE::Session::Cascading::swap($bad_sess, 'foo', 'bar'); };
like($@,qr/Assertion \(Stash referential integrity\) failed/, 'assert failure if stash referential integrity is violated');

$bad_sess->{info} = { };
eval { POE::Session::Cascading::swap($bad_sess, 'foo','bar'); };
like($@, qr/Assertion \(Stack integrity\) failed/, 'assert failure if stack integrity is violated');

$bad_sess->{stack} = 'pants';
eval { POE::Session::Cascading::swap($bad_sess, 'foo','bar') };
like($@, qr/Assertion \(Stack referential integrity\) failed/, 'assert failure if stack referential integrity is violated');

my $ret;
eval { $ret = $sess->swap(); };
is($ret, 0, 'returns 0 if passed no arguments');
undef $ret;

eval { $ret = $sess->swap('foo','bar'); };
is($ret, 0, 'returns 0 if passed non-existant state names');
