#$Header: /cvsroot/POE-Session-Cascading/POE/Session/Cascading.pm,v 1.9 2002/05/11 23:23:40 matt Exp $

# DOCUMENTATION #{{{

=head1 NAME

POE::Session::Cascading - Stack-like POE Sessions

=head1 AUTHOR

Matt Cashner (eek+cpan@eekeek.org)

=head1 DATE

$Date: 2002/05/11 23:23:40 $

=head1 SYNOPSIS

    POE::Session::Cascading->new(
        name => 'foo',
        events => [
            'state1' => \&state1,
            'state2 => \&state2,
        ],
    );

    sub state1 {
        my %args = @_;
        $args{KERNEL}->post('somewhere','somestate');
        # [ snip ]
        
    }
    
    sub state2 {
        my %args = @_;
        # [ snip ]
        
        $args{SESSION}->stop;
    }

=head1 DESCRIPTION

=head2 INTRODUCTION

POE::Session::Cascading provides a stack-like session for POE. 
Another way of saying it is that a Cascading session is like a big
switch statement.  In the above example, when C<state1> is called in
session C<foo>, C<&state1> gets executed. When it finishes, C<state2>
gets fired and C<&state2> gets executed.  If C<state2> is called in
session C<foo>, only C<state2> will get executed.

=head2 CONTROLLING PROPOGATION

Each state can decide whether chain propogation should continue or not. 
If the state wishes to stop chain propogation, it must call 
C<< $args{SESSION}->stop >>. Otherwise, chain propogation will continue.
A state can call C<< $args{SESSION}->go >> to forcibly allow chain 
propogation. This is largely superflous as this is the default option.

It would be appropriate to return call C<stop>, for instance, if the
state has determined that further action by this chain is unnecessary or
undesirable. The state might launch a different chain and cal C<stop>
to shutdown the current chain's propogation.

=head2 LAUNCHING A CHAIN

To initiate a chain, post a call to the relevant state with the
session's name. For instance, to activate the chain in the example
above, one would write:

    $poe_kernel->post('foo','state1');

Arguments passes to POE's post method will be passed directly to the
state and those which follow it.

=head2 WRITING A STATE

Cascading states are a bit different from the usual POE states, mainly
in the argument list.  Cascading states are passed a hash, containing
three entries. C<SESSION> contains a reference to the current session's
object. C<KERNEL> contains a reference to the POE kernel. C<ARGS>
contains an array reference of the arguments passed to the state.

Cascading states can do anything perl can.  Cascading states are passed 
a hash, containing three entries. C<SESSION> contains a reference to the 
current session's object. C<KERNEL> contains a reference to the POE 
kernel. C<ARGS> contains an array reference of the arguments passed 
to the state, including any data passed from the previous state..

=head1 METHODS

=cut

#}}}

package POE::Session::Cascading;

use warnings;
use strict;

use Carp;
use POE::Kernel;
use vars qw($VERSION %STACK %STACKINFO);

$VERSION = (qw($Revision: 1.9 $))[1];

# allow users to set the debug flag. also useful for the test suite
BEGIN {
    unless(defined &POE::Session::Cascading::DEBUG) {
        *POE::Session::Cascading::DEBUG = sub { 0 } ;
    }
}               

# Constants
sub CSC_STOP () { 0 }
sub CSC_OK () { 1 }


# sub new {{{

=head2 new()

    POE::Session::Cascading->new(
        name => 'foo',
        events => [
            step1 => \&step1,
            step2 => \&step2,
            step3 => \&step3,
        ]
    );


=cut

sub new {
    my $class = shift;
    croak("No arguments passed to new(). Cannot continue.") unless @_;
    croak("Odd number of arguments passed to new(). Cannot continue.") unless $#_ % 2;

    my %args = @_;
    
    croak("Argument 'name' not passed to new(). Cannot continue.") unless $args{name};
    croak("Argument 'events' not passed to new(). Cannot continue.") unless $args{events};
    croak("Argument 'events' not an array reference in new(). Cannot continue.") unless ref $args{events} eq 'ARRAY';
     
    my $sess_name = $args{name};
    my $event_stack = $args{events};

    croak("There is already a session by the name of '$sess_name'. Cannot continue.") if $STACK{$sess_name};

    print "Creating new stack named $sess_name\n" if DEBUG;
    for (my $i = 0; $i<@{$event_stack}; $i++) {
        my $name = $event_stack->[$i];
        my $coderef = $event_stack->[++$i];
        unless(ref $coderef eq 'CODE') {
            carp("Event '$name' not a code reference. Skipping.");
            next;
        }
        print "Registering state '$name' for session '$sess_name'\n" if DEBUG;
        push @{$STACK{$sess_name}}, $coderef;
        $STACKINFO{$sess_name}{$name} = $#{$STACK{$sess_name}};
    }
        
    my $self = {};
    $self->{name} = $sess_name;
    $self->{stack} = $STACK{$sess_name};
    $self->{info} = $STACKINFO{$sess_name};
    $self->{status} = CSC_OK;
     
    bless $self, $class;
    print "Allocating a new POE session for stack named $sess_name\n" if DEBUG;
    $POE::Kernel::poe_kernel->session_alloc($self);
    return $self;
}
#}}}

# sub _invoke_state {{{

# Handle events
sub _invoke_state {
    my ($self, $source_session, $state, $etc, $file, $line) = @_;
    print "Caught event $state\n" if DEBUG;
   
    assert($self,"Object integrity");
    assert($state,"State name");
    
    if($state eq '_start') {
        # Starting up. Set an alias and ensure persistence
        
        print "Setting kernel alias to $self->{name}\n" if DEBUG;
        $POE::Kernel::poe_kernel->alias_set($self->{name});
        $POE::Kernel::poe_kernel->delay('_ping',10);
        
    } elsif ($state eq '_stop') {
        # Shutting down. Delete the relevant stack.
        
        print "Deleting stack for $self->{name} in _stop\n" if DEBUG;
        delete $STACK{$self->{name}};
        
    } elsif ($state eq 'step') {
        # Take a step. Fire off the wrapper.
        # This is a happy call to make sure this blocks a lot less than it would otherwise.
        
        return $self->step(@{$etc});
        
    } elsif ($state eq '_ping') {
        # The ping state is used to keep the session alive.
        $POE::Kernel::poe_kernel->delay('_ping',10);

    } else {
        # A normal event. Do we know this event? Does it belong to stack?
        if(defined $self->{info}->{$state}) {
            # We know this state and this stack. Fire off the wrapper to process the stack.
            $POE::Kernel::poe_kernel->post($self->{name}, 'step', $STACKINFO{$self->{name}}{$state}, @{$etc});
            
        } else {
            # We have no idea what this event is. 
            print "ERR: Unknown event '$state' called on session '$self->{name}'\n" if DEBUG;
            
        } 
    }
}
#}}}

# sub step {{{

# Take a single step in the stack. 
# If appropriate, increment the counter and post the call to take the next step.
sub step {
    my $self = shift;
    my $itr = shift;
    my @args = @_;
    if($itr < @{$self->{stack}}) {
        my $ret = $self->{stack}->[$itr]->(SESSION => $self, KERNEL => $POE::Kernel::poe_kernel, ARGS => \@args);
        if ( ($self->{status} != CSC_STOP) && (++$itr < @{$self->{stack}})) {
            $self->{status} = CSC_OK;
            $POE::Kernel::poe_kernel->post($self->{name}, 'step', $itr, $ret, @args);
        } else {
            return CSC_STOP;
        }
    }
}
# }}}

=head2 stop

    $args{SESSION}->stop;

Instruct the current session to stop chain propogation.

=cut

sub stop {
    my $self = shift;
    $self->{status} = CSC_STOP;
}

=head2 go
    
    $args{SESSION}->go;

Instruct the current session to continue chain propgation.

=cut

sub go {
    my $self = shift;
    $self->{status} = CSC_OK;
}

sub DESTROY {
    my $self = shift;
    delete $STACK{$self->{name}};
    delete $STACKINFO{$self->{name}};
}

# um, this is assert, like in C. 
# if the condition is false, yell.
sub assert ($;$) {
    unless($_[0]) {
        Carp::confess( _fail_msg($_[1]) );
    }
    return undef;
} 

# Can't call confess() here or the stack trace will be wrong.
sub _fail_msg {
    my($name) = shift;
    my $msg = 'Assertion';
    $msg   .= " ($name)" if defined $name;
    $msg   .= " failed!\n";
    return $msg;
}     

# MORE DOCS {{{

=head1 BUGS AND KNOWN ISSUES

=over 4

=item * Cannot reorder the stack at runtime

=item * Cannot register or unregister a stack element at runtime

=item * Stack requires outside influence to start (is this actually a problem?)

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2002, Matt Cashner 

Permission is hereby granted, free of charge, to any person obtaining 
a copy of this software and associated documentation files (the 
"Software"), to deal in the Software without restriction, including 
without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to 
permit persons to whom the Software is furnished to do so, subject 
to the following conditions:

The above copyright notice and this permission notice shall be included 
in all copies or substantial portions of the Software.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

#}}}

1;
