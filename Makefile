M=share/man
I=lib/perl5/Net/PSYC.pm lib/perl5/Net/PSYC/Event.pm lib/perl5/Net/PSYC/Event/Event.pm lib/perl5/Net/PSYC/Event/Glib.pm lib/perl5/Net/PSYC/Event/IO_Select.pm lib/perl5/Net/PSYC/Client.pm bin/psycion bin/remotor
D=$(DESTDIR)

manuals: htdocs $I
	perldoc -oman lib/perl5/Net/PSYC.pm >$M/man3/Net::PSYC.3
	perldoc -oman lib/perl5/Net/PSYC/Event.pm >$M/man3/Net::PSYC::Event.3
#	perldoc -oman lib/perl5/Net/PSYC/Event/Event.pm >$M/man3/Net::PSYC::Event::Event.3
#	perldoc -oman lib/perl5/Net/PSYC/Event/Glib.pm >$M/man3/Net::PSYC::Event::Glib.3
#	perldoc -oman lib/perl5/Net/PSYC/Event/IO_Select.pm >$M/man3/Net::PSYC::Event::IO_Select.3
	perldoc -oman lib/perl5/Net/PSYC/Client.pm >$M/man3/Net::PSYC::Client.3
	perldoc -oman bin/psycion >$M/man1/psycion.1
	perldoc -oman bin/remotor >$M/man1/remotor.1
	perldoc -oman bin/psyccat >$M/man1/psyccat.1
	perldoc -oman bin/psyccmd >$M/man1/psyccmd.1
	perldoc -oman bin/psycplay >$M/man1/psycplay.1
	perldoc -oman bin/psyclisten >$M/man1/psyclisten.1
	perldoc -oman bin/syslog2psyc >$M/man1/syslog2psyc.1

html: htdocs
	perldoc -ohtml bin/remotor >htdocs/remotor.html
	perldoc -ohtml bin/psycion >htdocs/psycion.html
	perldoc -ohtml bin/psyccat >htdocs/psyccat.html
	perldoc -ohtml bin/psyccmd >htdocs/psyccmd.html
	perldoc -ohtml bin/psycplay >htdocs/psycplay.html
	perldoc -ohtml bin/psyclisten >htdocs/psyclisten.html
	perldoc -ohtml bin/syslog2psyc >htdocs/syslog2psyc.html

htdocs:
	mkdir -p $@ $M/man1 $M/man3

# just to give you a rough idea
install: $D/share
	# please provide destination prefix in export DESTDIR=/usr/local or so
	ln -f bin/psyccmd bin/psycplay
	install bin/* $D/bin
	ln -f $D/bin/psyccmd $D/bin/psycplay
	cp -rp lib/* $D/lib
	cp -rp share/* $D/share


