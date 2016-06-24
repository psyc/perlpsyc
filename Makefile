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

html: htdocs
	perldoc -ohtml bin/remotor >htdocs/remotor.html
	perldoc -ohtml bin/psycion >htdocs/psycion.html

htdocs:
	mkdir -p $@ $M/man1 $M/man3

# just to give you a rough idea
install: $D/share
	# please provide destination prefix in export DESTDIR=/usr/local or so
	install bin/* $D/bin
	cp -rp lib/* $D/lib
	cp -rp share/* $D/share


