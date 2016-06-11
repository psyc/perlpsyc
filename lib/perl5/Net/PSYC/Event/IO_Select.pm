package Net::PSYC::Event::IO_Select;

# TODO using fileno doesnt work for some funky file-handles ( perldoc -f fileno)
# but therefore select doesnt either. so.. who cares? In case someone knows a
# workaround for those, email me (I doubt that anybody is reading this anyway)

our $VERSION = '0.4';

use strict;

use base qw(Exporter);
use IO::Select;
use Net::PSYC qw(W);

#*W2 = *Net::PSYC::W0; 

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

our @EXPORT_OK = qw(init add remove start_loop stop_loop revoke);

my (%S, %cb, $LOOP, @T, $timeout, $timeout_cb, $idle_since);

%cb = (
	'r' => {},
	'w' => {},
	'e' => {},
    );

#   add (\*fd, type, cb, repeat)
sub add {
    my ($fd, $type, $cb, $repeat) = @_;

    unless ($cb && ref $cb eq 'CODE') {
	W0('You need a proper callback for add()! (has to be a code-ref)');
	return;
    }

    W2('add(%s, %s, %p, %d)', $fd, $type, $cb, $repeat||0);

    if ($type eq 'r' or $type eq 'w' or $type eq 'e') {
	$S{$type} = new IO::Select() unless $S{$type};
	$S{$type}->add($fd);
	vec($S{$type}->[0], fileno($fd), 1) = 1;
    } elsif ($type eq 't') {
	my $i = 0;
	my $t = mytime() + $fd;
	while (exists $T[$i] && $T[$i]->[0] <= $t) {
	    $i++;
	}
	splice(@T, $i, 0, [$t, $cb, ($repeat) ? 1 : 0, $fd]);
	return scalar($cb).$fd;
    } elsif($type eq 'i') {
	if ($fd <= 0) {
	    W0('a timeout has to be greater than 0.');
	    return 0;
	}
	$timeout = $fd;
	$timeout_cb = $cb;
	return;
    } else { 
	die "Unknown Event-type '$type'!\n";
    }
    $cb{$type}->{fileno($fd)} = [ (!defined($repeat) || $repeat) ? -1 : 1, $cb ];
    1;
}

sub revoke {
    my $id = shift;
    my $name = fileno($id);
    W2('revoke(%s)', $name);
    my $type = shift;

    unless ($type eq 'r' || $type eq 'w' || $type eq 'e') {
	W0('you cannot revoke an event that is not read, write or exception.');
	return 0;
    }
    
    if (exists $cb{$type}->{$name} and $cb{$type}->{$name}[0] == 0) {
	vec($S{$type}->[0], $name, 1) = 1;
	$cb{$type}->{$name}[0] = 1;
	W2('revoked %s', $id);
	return 1;
    }

    return 0;
}

#   remove (\*fd, type )
sub remove {
    my $id = shift;
    my $type = shift;
    W2('remove(%s)', $id);

    # this is actually 'not so' smart. i will do a better one on christmas.
    if ($type eq 't') {
	my $i = 0;
	foreach (@T) {
	    if (scalar($T[$i]->[1]).$T[0]->[3] eq $id) {
		splice(@T, $i, 1);
		return 1;
	    }
	    $i++;
	}
    } elsif ($type eq 'i') {
	$timeout = undef;
	$timeout_cb = undef;
    }

    my $name = fileno($id);

    if ($type eq 'r' || $type eq 'w' || $type eq 'e') {
	if (exists $cb{$type}->{$name}) {
	    vec($S{$type}->[0], $name, 1) = 0;
	    $S{$type}->remove();
	}
    }
}

sub start_loop {
    my (@E, $sock, $name, @queue);
    
    # @queue
    
    $idle_since = mytime();
    $LOOP = 1;
    my $time;
    LOOP: while ($LOOP) {
	my $is_timer = undef;

	if (scalar(@T) && !scalar(@queue)) {
	    $is_timer = 1;
	    $time = $T[0]->[0] - mytime();
	    if ($time < 0) {
		$time = 0;
		@E = ([],[],[]);
		goto TIME;
	    }
	    # we could do a goto here and leave out the select call. that
	    # however would keep rwe events from being called in case we have
	    # many many timers. As long as we dont have any means of handling
	    # different priorities we stay with this solution and try to be
	    # fair.
	    # TODO: think again
	} elsif (scalar(@queue)) { 
	   $time = 0;
	} else {
	    $time = undef; 
	}

	# i build in these timers without thinking much about it.. 
	# maybe there is a smarter solution, less calculation etc.
	#
	my $idle_time;
	if ($timeout) {
	    $idle_time = mytime() - $idle_since;

	    if (!defined($time) || $time > $timeout - $idle_time) {
		$time = $timeout - $idle_time;
		$is_timer = 0;
	    }
	}

	my ($rmask, $wmask, $emask) = ($S{'r'}->[0], $S{'w'}->[0], 
					$S{'e'}->[0]);
	W2('Selecting with time %d.', $time);

	@E = IO::Select::select(defined($rmask) && $rmask =~ /[^\0]/ 
				    ? $S{'r'} : undef, 
				defined($wmask) && $wmask =~ /[^\0]/ 
				    ? $S{'w'} : undef, 
				defined($emask) && $emask =~ /[^\0]/ 
				    ? $S{'e'} : undef, 
				$time);
	TIME:

	if ($is_timer) {
	    if (scalar(@T) && $T[0]->[0] <= mytime()) {
		my $event = shift @T;

		if ($event->[1]->() && $event->[2]) { # repeat!
		    add($event->[3], 't', $event->[1], 1);
		}
		$idle_since = mytime() if ($timeout);
		goto REPLAY;
		#next LOOP unless ($time);
	    }
	    # dont do a next if there is still a queue. $is_timer is undefined
	    # if there are items in the queue.. very very complicated. ,)
	    #
	    # maybe rewrite this whole logic, it seems to get redundant and
	    # too complex
	} elsif (defined($is_timer) &&
		 (!defined($E[0]) || scalar(@{$E[0]}) == 0) && 
		 (!defined($E[1]) || scalar(@{$E[1]}) == 0) && 
		 (!defined($E[2]) || scalar(@{$E[2]}) == 0)) {

	    if ($timeout) {
		$timeout_cb->(); 
		$idle_time = 0;
		$idle_since = mytime();
	    }
	    next LOOP;
	    #goto REPLAY;
	}

	foreach $sock (@{$E[0]}) { # read    
	    $idle_since = mytime() if ($timeout);
	    $name = fileno($sock);
	    next unless (exists $cb{'r'}->{$name});
	    my $event = $cb{'r'}->{$name};

	    W2('Read event on %p (%d).', $sock, $name);

	    if ($event->[0] != 0) {	 # repeat or not	
		if ($event->[0] > 0) {
		    $event->[0] = 0;
		    vec($S{'r'}->[0], $name, 1) = 0;
		}
		
		if ($event->[1]->($sock) == -1) {
		    push(@queue, [$event->[1], $sock, 1]);   
		}
	    }
	}

	foreach $sock (@{$E[1]}) { # write
	    $idle_since = mytime() if ($timeout);
	    $name = fileno($sock);
	    next unless (exists $cb{'w'}->{$name});
	    my $event = $cb{'w'}->{$name};

	    W2('Write event on %p ($d).', $sock, $name);
	    
	    if ($event->[0] != 0) {	 # repeat or not
		if ($event->[0] > 0) {
		    $event->[0] = 0; 
		    vec($S{'w'}->[0], $name, 1) = 0;
		}

		if ($event->[1]->($sock) == -1) {
		    push(@queue, [$event->[1], $sock, 1]);   
		}
	    }
	}

	foreach $sock (@{$E[2]}) { # error
	    $idle_since = mytime() if ($timeout);
	    $name = fileno($sock);
	    next unless (exists $cb{'e'}->{$name});
	    my $event = $cb{'e'}->{$name};
	    
	    W2('Error event on %p ($d).', $sock, $name);

	    if ($event->[0] != 0) {	 # repeat or not
		if ($event->[0] > 0) {
		    $event->[0] = 0;
		    vec($S{'e'}->[0], $name, 1) = 0;
		}

		if ($event->[1]->($sock) == -1) {
		    push(@queue, [$event->[1], $sock, 1]);   
		}
	    }
	}

	REPLAY:

	foreach (0 .. $#queue) {
	    my $event = shift @queue;
	    if ($event->[0]->($event->[1], $event->[2]++) == -1) {
		push(@queue, $event);
	    }
	}
    }
    return 1;
}

sub stop_loop {
    $LOOP = 0;
    return 1;
}

1;
