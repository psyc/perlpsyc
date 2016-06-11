#!/usr/bin/perl

use strict;
use Test::Simple tests => 1;

use Time::HiRes qw(gettimeofday tv_interval);
use Net::PSYC qw(:event setDEBUG);

my $c = 0;
my ($f, $s1, $m1);

sub t {
    $c++;

    if ($c == 3) {
	ok(1, 'Timeout events.');
	stop_loop();
    }
}

add(1, 'i', \&t);
print "!\tIf nothing happens for more than 5 seconds,\n!\tterminate the test and report the failure!\n";
start_loop();

__END__
