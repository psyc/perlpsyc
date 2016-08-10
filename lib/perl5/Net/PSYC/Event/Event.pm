package Net::PSYC::Event::Event;

our $VERSION = '1.0';

use strict;
use Event qw(loop unloop);
use Net::PSYC qw(W);

use base qw(Exporter);
our @EXPORT_OK = qw(init add remove start_loop stop_loop revoke);

my (%s, %revoke, $idle);

#   add (\*fd, type, cb, repeat)
sub add {
    my ($fd, $type, $cb, $repeat) = @_;
    W2('add(%s, %s, %p, %d)', $fd, $type, $cb, $repeat||0);
    if (!$type || !$cb || !ref $cb eq 'CODE') {
	die 'Net::PSYC::Event::Event::add() requires type and a callback!';
    }
    
    my $watcher;
    if ($type eq 't') {
	$watcher = Event->timer( after => $fd,
				 repeat => defined($repeat) ? $repeat : 0,
				 cb => (!$repeat) 
		    ? sub { remove(($watcher, 't')); $cb->() } 
		    : sub { remove(($watcher, 't')) unless $cb->() });	
	$s{'t'}->{$watcher} = $watcher;
	return $watcher;
    } elsif ($type eq 'i') {
	$idle = Event->idle( cb => $cb,
			     min => $fd );
    } elsif ($type =~ /^[rwe]$/) {
	my $count;
	my $sub = sub { 
	    if ($cb->($fd, $count++) == -1) {
		$watcher->now();
	    } else {
		$count = 0;
	    }
	};
	$watcher = Event->io( fd => $fd,
			      cb => $sub,
			      poll => $type,
			      repeat => defined($repeat) ? $repeat : 1);
	$s{$type}->{$fd} = $watcher;
	$revoke{$type}->{$fd} = $watcher if (defined($repeat) && $repeat == 0);
    } else {
	die "read the docu, you punk! '$type' is _not_ a valid event type.";
    }

}
#   revoke( \*fd, flags )
sub revoke {
    my $sock = shift;
    my $name = $sock;
    my $type = shift;
    W2('revoked %s', $name);
    if ($type eq 't' || $type eq 'i') {
	W0('You cannot revoke idle or timer PSYC::Events.');
	return;
    }

    if ($type eq 'r' || $type eq 'w' || $type eq 'e') {
	$s{$type}->{$name}->again() if(exists $s{$type}->{$name});
	return 1;
    }

    W0('Unknown PSYC::Event type: %s.', $type);
}

#   remove ( \*fd, flag )
sub remove {
    my $sock = shift;
    my $name = ($sock);
    my $flag = shift;
    W2('removing %s', $name);

    if ($flag eq 'i') {
	$idle->cancel();
	$idle = undef;
	return;
    }
    unless ($flag =~ /^[rewt]$/) {
	W0('Unknown PSYC::Event type: %s.', $flag);	
	return 0;
    }
    return unless (exists $s{$flag}->{$name});
    $s{$flag}->{$name}->cancel();
    delete $s{$flag}->{$name};
    delete $revoke{$flag}->{$name} if ($flag ne 't' && $flag ne 'i');
}

sub start_loop {
    !loop();
}

sub stop_loop {
    unloop();
}


1;
