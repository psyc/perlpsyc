#!/usr/bin/perl

use strict;
BEGIN {	
    unless (eval "require Event") {
	print "You don't have Event.pm installed. No Problem.\nSkipping this test.\n";
	exit;
    }
    require Test::Simple;
    import Test::Simple qw(tests 1);
    require Time::HiRes;
    import Time::HiRes qw(gettimeofday tv_interval);
    require Net::PSYC;
    import Net::PSYC qw(Event=Event);
}

my $c = 0;
my ($s1, $m1, $f);

sub t {
    $c++;

    if ($c == 3) {
	ok(1, 'Timeout events with Event.');
	stop_loop();
    }

    1;
}

add(1, 'i', \&t);
print "!\tIf nothing happens for more than 5 seconds,\n!\tterminate the test and report the failure!\n";
start_loop();

__END__
