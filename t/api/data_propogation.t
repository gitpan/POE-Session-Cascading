
use Test::More qw(no_plan);
use warnings;
use strict;

local $SIG{__WARN__} = sub { $@ = shift; die $@; };

BEGIN { 
    use_ok('POE::Session::Cascading'); 
}
my $order;
POE::Session::Cascading->new(
    name => 'proptest',
    events => [
        'state1' => sub { return { foo => 1 } },
        'state2' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $ref->{foo} .= 2; return $ref;},
        'state3' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $ref->{foo} .= 3; return $ref;},
        'state4' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $ref->{foo} .= 4; return $ref; },
        'state5' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $ref->{foo} .= 5; return $ref; },
        'state6' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $ref->{foo} .= 6; return $ref; },
        'state7' => sub { my %args = @_; my $ref = shift @{$args{ARGS}}; $order = $ref->{foo}; warn $order; $args{SESSION}->stop; },
    ],      
);


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state1"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'123456','data propogation across states succesful');


