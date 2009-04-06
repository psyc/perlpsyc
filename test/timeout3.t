# vim:syntax=perl
#!/usr/bin/perl -w

use strict;
BEGIN {	
    unless (eval "require Event::Lib") {
	print "You don't have Event::Lib.pm installed. No Problem.\nSkipping this test.\n";
	exit;
    }
    require Test::Simple;
    import Test::Simple qw(tests 1);
    require Time::HiRes;
    import Time::HiRes qw(gettimeofday tv_interval);
    require Net::PSYC;
    import Net::PSYC qw(Event=libevent);
}

my $c = 0;
my ($s1, $m1, $f);

sub t {
    $c++;

    if ($c == 3) {
	ok(1, 'Timeout events with Event::Lib.');
	stop_loop();
    }

    1;
}

add(1, 'i', \&t);
print "!\tIf nothing happens for more than 5 seconds,\n!\tterminate the test and report the failure!\n";
start_loop();

__END__
