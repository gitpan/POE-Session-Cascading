# Test state propogation 

use Test::More tests => 9;
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
        'state1' => sub { $order .= 1; },
        'state2' => sub { $order .= 2; },
        'state3' => sub { $order .= 3; },
        'state4' => sub { $order .= 4; },
        'state5' => sub { $order .= 5; },
        'state6' => sub { $order .= 6; },
        'state7' => sub { my %args = @_; $order ||= 'undef'; warn $order;  $args{SESSION}->stop; },
    ],      
);


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state1"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'123456','whole tree propogation');
undef $order;


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state2"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'23456','partial tree propogation (2-6)');
undef $order;

eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state3"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'3456','partial tree propogation (3-6)');
undef $order;

eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state4"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'456','partial tree propogation (4-6)');
undef $order;


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state5"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'56','partial tree propogation (5-6)');
undef $order;


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state6"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'6','partial tree propogation (6-6)');
undef $order;


eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state7"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'undef','single state propogation (7)');
undef $order;

eval {
    use POE; 
    POE::Session->create( inline_states => { _start => sub { $_[KERNEL]->post("proptest","state3"); } , _stop => sub { $_[KERNEL]->signal('INT') } } ); 
    $poe_kernel->run;
};
is($order,'3456','partial tree propogation (3-6)');
undef $order;


