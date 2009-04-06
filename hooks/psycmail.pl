#!/usr/bin/perl
# _______________________________________________
# this script is SUPERCEDED by the implementation
# in C available in the psyced distribution.
# see also	    http://about.psyc.eu/psycmail
# ===============================================
#
# UNIX MAIL FILTER FOR MAIL RECEPTION NOTIFICATION
#
# psycmail can be used as filter by procmail and will forward
# sender and subject to a UNI on a psyc server - so it's
# some sort of a textual remote biff.
#
# typical usage in .procmailrc:
#
#	:0 hc
#	|/usr/local/mbin/psycmail psyc://psyced.org/~user
#
# or in .forward:
#
#	\user,|"/usr/depot/mbin/psycmail psyc://psyced.org/~user"
#
# "standalone" implementation currently not using the psyc library

$target  = shift || 'psyced.org';
$method  = shift || '_notice_received_email';
$port    = shift || 4404;
$nick	 = shift;

if ($target =~ m!^psyc://([^/]+)!i) {
	$remote = $1;
	($remote, $port) = ($1,$2) if $remote =~ m!^([^:]+):(\d+)\b!;
} elsif ($target =~ m!^(\w+)\@(\S+)$!i) {
	$remote = $2;
	$target = "psyc://$remote/~$1";
} else {
	$remote = $target;
	$target = "psyc://$remote";
	$target .= "/~$nick" if $nick;
}

if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
die "No port" unless $port;

# perl4 code is commented out here
#
# $iaddr = (gethostbyname($remote))[4]		|| die "no host: $remote";
# $sockaddr = 'S n a4 x8'; $paddr = pack($sockaddr, 2, $port, $iaddr);
# socket(S, 2, 1, 6)				|| die "socket: $!";
#
use Socket;
$iaddr   = inet_aton($remote)			|| die "no host: $remote";
$paddr   = sockaddr_in($port, $iaddr);
socket(S, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket: $!";

connect(S, $paddr)				|| die "connect: $!";
select S; $|=1; select STDOUT;

$sender = $ENV{HOST} || '';
$sender .= 'Mail';

print S <<X;
.
X

if (defined($_ = <S>) && !/^\./) {
	print if s/^=//;
}
while (defined($_ = <S>) && !/^\./) {
	print if s/^=//;
}
print "\n";

while (defined($_ = <stdin>)) {
	last if /^\s*$/;

	# next if /:/ && ! /^(From|Subject|To|Cc):/i;
#	next if /:/ && ! /^(From|Subject):/i;
#	next if /^\s/; # && /\s(id|by) /;
	# next if /^\s/ && /\s\(envelope-from /;
#	print S $_ unless /^\.\s*$/;

	$from = $1 if /^From: (.*)$/i;
	$subject = $1 if /^Subject: (.*)$/i;
}

			# From: "Real Name" <user@domain>
($source, $name) = $from =~ /^"(.*)"\s+<(\S+@\S+)>$/
			# From: Real Name <user@domain>
or ($name, $source) = $from =~ /^(.*)\s+<(\S+@\S+)>$/
			# From: user@domain "Real Name"   ... hardly in use
or ($source, $name) = $from =~ /^([^"\s]+@[^"\s]+)\s+"(.*)"$/
			# From: <user@domain>
or ($source) = $from =~ /^<(\S+@\S+)>$/
			# From: user@domain
or $source = $from;

$name = $source unless $name;

# egal, mailto: als source wird eh noch nicht akzeptiert..
print S <<X;
:_target	$target

:_nick_mailer	$sender
:_nick_long	$name
:_origin	$from
:_subject	$subject
$method
([_nick_mailer]) [_nick_long]: [_subject]
.

_request_circuit_shutdown
.
X
# _message_email_subject

# at this point we should wait for the other side to close the socket.. argl
close (S)					|| die "close: $!";
exit;

