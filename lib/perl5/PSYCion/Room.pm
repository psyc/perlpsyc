package PSYCion::Room;

use strict;
use base 'Exporter';

our @EXPORT = qw(%actions);

our %actions = (
'say' => sub {
    my $self = shift;
    my $line = shift;
    Net::PSYC::Client::sendmsg($self->{'uni'}, '_message_public', $line,
	{
	_color => sprintf('#%x%x%x', rand(120)+120, rand(120)+120, 
	    rand(120)+120)
	});
    return 1;
},
'member' => sub {
    my $self = shift;
    Net::PSYC::Client::sendmsg(UNI(), '_request_members');
},
'status' => sub {
    my $self = shift;
    Net::PSYC::Client::sendmsg(UNI(), '_request_status');
},
);
