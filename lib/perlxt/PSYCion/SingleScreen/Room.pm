package PSYCion::SingleScreen::Room;

use strict;

use Net::PSYC qw(psyctext);
use Net::PSYC::Client qw(sendmsg NICK UNI);
use PSYCion::Prompt;
use PSYCion::Room;

use base 'PSYCion::SingleScreen::Gui';

my (%rooms);
my ($last, $current);

sub last { $last }
sub current { $current }

sub new {
    my ($class, $uni, $name, $silent) = @_;
    my $self = PSYCion::SingleScreen::Gui::new($class, $name, $silent);
    $self->{'uni'} = $uni;
    $self->{'name'} = $name;
    $self->{'type'} = 'place';
    $self->{'members'} = {};
    $rooms{$uni} = $self;
    $self;
}

sub activate {
    my $self = shift;
    $current = $self;
    $self->SUPER::activate();
}

sub deactivate {
    my $self = shift;
    $last = $self;
    $self->SUPER::deactivate();
}

# leave all rooms..
sub leave_all {
    foreach (keys %rooms) {
	sendmsg($_, '_request_leave');
    }
}

# only messages to be printed get here
sub msg {
    my ($self, $source, $mc, $data, $vars) = @_;
    
    $mc =~ s/^_message_public/$&_active/ 
	if ($self eq PSYCion::Window::current());
    return $self->out($mc, $data, $vars);
}

sub leave {
    my ($self, $nick) = @_;
    delete $self->{'members'}->{$nick};    
}

sub enter {
    my ($self, $nick, $uni) = @_;
    $self->{'members'}->{$nick} = $uni;
}

sub members {
    my $self = shift;
    $self->{'members'} = shift;
}

sub leanforwardandchokeyourself {
    my $self = shift;
    delete $rooms{$self->{'uni'}};
    if ($last eq $self) {
	$last = 0;
    }
    $self->remove();
}

sub alias {
    my ($alias, $cmd) = @_;
    if (exists $actions{$cmd}) {
	$actions{$alias} = $actions{$cmd};
	return 1;
    }
    return 0;
}

sub cmd {
    my $self = shift;
    my $cmd = shift;

    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }

    $self->SUPER::cmd($cmd, @_);
}


1;
