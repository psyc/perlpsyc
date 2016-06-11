package Net::PSYC::Event::Qt::Repeat;

use strict;
use Qt::isa qw(Qt::Object);
use Qt::attributes qw(cb fd n);

sub NEW {
    shift->SUPER::NEW();
    fd = $_[0]; 
    cb = $_[1];
}

sub event {
    no strict 'subs';
    my $c = cb;
    $c->(fb);
}

sub setNotifier {
    n = shift;
}

package Net::PSYC::Event::Qt::OneShot;

use strict;
use Qt::isa qw(Qt::Object);
use Qt::attributes qw(cb fd n);

sub NEW {
    shift->SUPER::NEW();
    fd = $_[0]; 
    cb = $_[1];
}

sub event {
    no strict 'subs';
    my $c = cb;
    $c->(fb);

    n->setEnabled(0);
}

sub setNotifier {
    n = shift;
}

package Net::PSYC::Event::Qt;

use strict;
use Net::PSYC qw(W);
use Qt;
use Qt::debug qw(all);

our $VERSION = '0.1';

use base qw(Exporter);
our @EXPORT_OK = qw(add remove start_loop stop_loop revoke);

my (%revoke);

#   add (\*fd, flags, cb[, repeat])
sub add {
    my ($fd, $type, $cb, $repeat) = @_;
    W2('Qt->add(%s, %s, %s)', $fd, $type, $cb);

    my $o;
    if (defined($repeat) && $repeat == 0) { # one-shot
	$o = new Net::PSYC::Event::Qt::OneShot($cb);
    } else {
	$o = new Net::PSYC::Event::Qt::Repeat($cb);
    }

    my $name = fileno($fd);
 
    # one-shot event!
    my $event = ($type eq 'r') ? Qt::SocketNotifier::Read() :
		($type eq 'w') ? Qt::SocketNotifier::Write() :
		($type eq 'e') ? Qt::SocketNotifier::Exception() :
	die "Unknown event type '$type'\n";

    $o->{'n'} = Qt::SocketNotifier( $name, $type ); 
    Qt::Object::connect($o->{'n'}, 'activated(int)', $o, 'event()');

    $revoke{$type}->{$name}->setNotifier($o->{'n'});

}
#   revoke ( \*fd )
sub revoke {
    my $name = fileno(shift);
    my $type = shift||'r';
    W2('Qt->revoke(%s)', $name);

    if (defined($name) && exists $revoke{$type}->{$name}) {
	$revoke{$type}->{$name}->{'n'}->setEnabled(1);
    }
}

#   remove (\*fd[, type] )
sub remove {
    my ($name, $type) = (fileno(shift), shift);
    W2('Qt->remove(%s, %s)', $name, $type);
    
    # remove??
    if (defined($name) && exists $revoke{$type}->{$name}) {
	$revoke{$type}->{$name}->{'n'}->setEnabled(0);
    }

}

sub start_loop {
    die 'Net::PSYC::Event::Qt does not offer an event-loop.';
}

sub stop_loop {
    start_loop();
}

1;


1;
