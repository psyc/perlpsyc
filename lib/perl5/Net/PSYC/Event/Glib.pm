package Net::PSYC::Event::Glib;

our $VERSION = '0.1';

use strict;

use Net::PSYC qw(W);
use Glib;

use base qw(Exporter);
our @EXPORT_OK = qw(init add remove start_loop stop_loop revoke);

my (%r, %w, %e, %revoke);

#   add (\*fd, flags, cb[, repeat])
sub add {
    my ($fd, $flags, $cb, $repeat) = @_;
    W2('Glib->add(%s, %s, %s)', $fd, $flags, $cb);
    W0('add () using Glib requires a callback! (has to be a code-ref)') 
	if (!$cb || ref $cb ne 'CODE' );
    
    # one-shot event!
    if (defined($repeat) && $repeat == 0) {
	my $t = $cb;
	$cb = sub {
		    remove($fd, $flags) if ($t->() != -1);
		};
	$revoke{fileno($fd)} = [ $fd, $flags, $cb ];
    }

    if ($flags =~ /r/) {
	$r{fileno($fd)} = Glib::IO->add_watch(fileno($fd), 'in', $cb);
    }
    if ($flags =~ /w/) {
	$w{fileno($fd)} = Glib::IO->add_watch(fileno($fd), 'out', $cb);
    }
    if ($flags =~ /e/) {
	$e{fileno($fd)} = Glib::IO->add_watch(fileno($fd), 'err', $cb);
    }
}

#   revoke ( \*fd )
sub revoke {
    my $name = fileno(shift);
    W2('Glib->revoke(%s)', $name);
    if (exists $revoke{$name}) {
	my $flags = $revoke{$name}->[1];
	return if ((!$flags =~ /r/ || exists $r{$name}) && (!$flags =~ /w/ || exists $w{$name}));
	add(@{$revoke{$name}});
    }
}

#   remove (\*fd[, flags] )
sub remove {
    my ($name, $flags) = (fileno(shift), shift);
    W2('gtk2->remove(%s, %s)', $name, $flags);
    
    if ((!$flags || $flags =~ /r/) && exists $r{$name} ) {
	Glib::IO->remove_watch( delete $r{$name} );
    }
    if ((!$flags || $flags =~ /w/) && exists $w{$name}) {
	Glib::IO->remove_watch( delete $w{$name} );
    }
    if ((!$flags || $flags =~ /e/) && exists $w{$name}) {
	Glib::IO->remove_watch( delete $e{$name} );
    }
}

sub start_loop {
    die 'Net::PSYC::Event::Glib does not offer an event-loop.';
}

sub stop_loop {
}

1;
