# $Header: /home/sungo/src/sungo/POE-Session-Cascading/t/MockObject.pm,v 1.3 2002/05/12 00:22:50 matt Exp $
package MockObject;

use warnings;
use strict;
use vars qw($AUTOLOAD);

sub new {
    my $class = shift;
    my $self = { CATCH => undef };
    return bless $self, $class;
}

sub catch {
    my $self = shift;
    my $catch = shift;
    $self->{CATCH} = $catch;
}

sub AUTOLOAD {
    my $self = shift;
    my ($method, $ret);
    ($method = $AUTOLOAD) =~ s/.*:://;
    return if $method eq 'DESTROY';
    if(ref $self) {
        if($self->{CATCH}) {
            if($method eq $self->{CATCH}) {
                warn "Caught $self->{CATCH}";
            } 
        }
    }
}
 
1;
