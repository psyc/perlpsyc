DINGS=perl -I../lib/perl5 -Wall
all: parse tcp udp compress timer event 
parse:
	${DINGS} psyc_parse.t
tcp:
	${DINGS} tcp.t
udp:
	${DINGS} udp.t
compress:
	${DINGS} compress.t
timer:
	${DINGS} timer1.t && ${DINGS} timer2.t && ${DINGS} timer3.t
timeout:
	${DINGS} timeout1.t && ${DINGS} timeout2.t && ${DINGS} timeout3.t
event:
	${DINGS} eventtcp.t && ${DINGS} libeventtcp.t
