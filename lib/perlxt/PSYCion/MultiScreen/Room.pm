package PSYCion::MultiScreen::Room;

use Net::PSYC qw(psyctext);
use Net::PSYC::Client qw(sendmsg NICK UNI);
use PSYCion::Room;

use base 'PSYCion::MultiScreen::Gui';
use strict;

my ($last, $current, %rooms);

sub last { $last }
sub current { $current }

sub new {
    my ($class, $uni, $name, $silent) = @_;
    my $self = PSYCion::MultiScreen::Gui::new($class, $name, $silent);
    $self->{'uni'} = $uni;
    $self->{'name'} = $name;
    $self->{'type'} = 'place';
    $self->{'members'} = {};
    $rooms{$uni} = $self;
    return $self;
}

# leave all rooms..
sub leave_all {
    foreach (keys %rooms) {
	sendmsg($_, '_request_leave');
    }
}

sub input {
    my $self = shift;
    my $line = shift;
    if ($line =~ /^\//) {
	return;
    }
    sendmsg($self->{'uni'}, '_message_public', $line);
}

# only messages to be printed get here
sub msg {
    my ($self, $source, $mc, $data, $vars) = @_;
    $self->out($mc, $data, $vars);
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

sub activate {
    my $self = shift;
    $current = $self;
    $self->SUPER::activate();
}

sub deactivate {
    my $self = shift;
    $last = $self if ($current ne $self);
    $self->SUPER::deactivate();
}

sub status {
    my $self = shift;
    
}

sub leanforwardandchokeyourself {
    my $self = shift;
    delete $rooms{$self->{'uni'}};
    if ($last eq $self) {
	$last = 0;
    }
    $self->remove();
    my $n = PSYCion::Window::current();
    return Net::PSYC::stop_loop() unless $n;
    $n->draw();
}

sub cmd {
    my $self = shift;
    my $cmd = shift;

    if ($cmd && exists $actions{$cmd}) {
        my $t = $actions{$cmd}->($self, @_);
        return $t if (defined($t));
    }
    return $self->SUPER::cmd($cmd, @_);
}

sub debug {
    my $self = shift;
    my $d = shift;
    $self->out('_ION_info', $d);
}

sub alias {
    my ($alias, $cmd) = @_;
    if (exists $actions{$cmd}) {
	$actions{$alias} = $actions{$cmd};
	return 1;
    }
    return 0;
}

1;
