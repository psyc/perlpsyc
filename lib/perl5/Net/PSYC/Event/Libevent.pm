package Net::PSYC::Event::Libevent;

use strict;
use base qw(Exporter);
use Event::Lib;
use Net::PSYC qw(W);

our @EXPORT_OK = qw(init add remove start_loop stop_loop revoke);

sub BEGIN {
    if (eval { Time::HiRes::time() }) {
        eval qq {
            sub mytime() { Time::HiRes::time() }
        };
    } else {
        eval qq {
            sub mytime() { time() }
        };
    }
}

# keep events in here to revoke them
my (%events, $LOOP, $timeout, $timeout_cb);

sub add {
    my ($fd, $type, $cb, $repeat) = @_;
    W2('add(%s, %s, %p, %d)', $fd, $type, $cb, $repeat||0);
    my ($event, $sub);

    if ($type eq 't') {
	if (defined($repeat) && $repeat == 1) {
	    $sub = sub {
		my $event = shift;
		if ($cb->()) {
		    $event->add($fd);
		}
	    }
	} else {
	    $sub = $cb;
	}
	$event = timer_new($sub);
	$event->add($fd);
	return $event;
    } elsif ($type eq 'i') {
	$timeout = $fd;
	$timeout_cb = $cb;
    } else {
	my $flags;
	if (defined($repeat) && $repeat == 0) {
	    $flags = 0;
	    $sub = sub {
		my $event = shift;
		$cb->($event->fh);
	    };
	} else {
	    $flags = EV_PERSIST;
	    my $count = 0;
	    $sub = sub { 
		my $event = shift;	
		my $d = $cb->($event->fh, $count++);

		if ($d == -1) {
		    $sub->($event);
		} else {
		    $count = 0;
		}
	    };
	}
	if ($type eq 'r') {
	    $flags |= EV_READ;
	} elsif ($type eq 'w') {
	    $flags |= EV_WRITE;
	} elsif ($type eq 'e') {
	    W0('There is no exception handling for file descriptors in libevent.');
	    return 0;
	}
	$event = event_new($fd, $flags, $sub);
	$event->add();
	$events{$fd}{$type} = $event;
    }

    1;
}

sub revoke {
    my $fd = shift;
    my $type = shift;

    if (exists $events{$fd} && exists $events{$fd}{$type}) {
	if ($events{$fd}{$type}->pending()) {
	    W2('Revoking an already running event %s on %s.', $type, $fd);
	    return 1;
	}
	$events{$fd}{$type}->add(); 
	W2('revoked %p', $fd);
	return 1;
    } else {
	W0('Trying to revoke an unknown event (%s on %s).', $type, $fd);
	return 0;
    }
}

sub remove {
    my $fd = shift;
    my $type = shift;
    W2('removing %p', $fd);

    if ($type eq 't') {
	$fd->remove();
	return 1;
    }
    
    if ($type eq 'i') {
	$timeout = undef;
	$timeout_cb = undef;
	return 1;
    }
    
    if (exists $events{$fd} && exists $events{$type}) {
	$events{$fd}{$type}->remove(); 
	return 1;
    }

    W0('Trying to remove an unknown event (%s on %s).', $type, $fd);
    return 0;
}

sub start_loop {
    $LOOP = 1;

    while ($LOOP) {

	unless ($timeout) {
	    event_one_loop();
	    next;
	}

	my $t = mytime();
	event_one_loop($timeout);

	# time returns the integer part. we have no way of doing this 
	# more correctly without using Time::HiRes 
	if (mytime() - $t >= $timeout) {
	    $timeout_cb->();
	}
    }

    return 1;
}

sub stop_loop {
    $LOOP = 0;
}

1;
