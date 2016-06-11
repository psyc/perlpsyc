package PSYCion::Person;
# to be imported by ::Person.

use base 'Exporter';
use strict;

our ($reply); # person from who we got the last message

sub reply { $reply }
sub set_reply {
    $reply = shift;
}

our @EXPORT = qw(%actions);

our %actions = (
'say' => sub {
    my $self = shift;
    my $data = join(' ', @_);
    # actually should be anything which isnt psyc:
    if ($self->{'uni'} =~ /^(?:xmpp|psyc):/ 
	&& $self->{'name'} eq $self->{'uni'}) {
        return PSYCion::Main::cmd('execute', 'tell '.$self->{'uni'}.' '.$data);
    }
    Net::PSYC::Client::sendmsg($self->{'uni'}, '_message_private', $data,
            { _nick_target => $self->{'name'}});
    return 1;
},
);

