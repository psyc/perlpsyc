package PSYCion::MultiScreen::Person;

use Net::PSYC::Client qw(sendmsg NICK);
use PSYCion::Person;

use base 'PSYCion::MultiScreen::Gui';

sub new {
    my $class = shift;
    my $uni = shift;
    my $name = shift;
    my $v = PSYCion::MultiScreen::Gui::new($class, $name);
    $v->{'uni'} = $uni;
    $v->{'name'} = $name;
    $v->{'type'} = 'person';
    $last = $v unless($last);
    return $v;
}

sub msg {
    my ($self, $source, $mc, $data, $vars) = @_;
    $last = $self if ($mc =~ /^_message_private$/); 
    $self->out($mc, $data, $vars);
}

sub status {
    my $self = shift;
}

sub cmd {
    my $self = shift;
    my $cmd = shift;
    
    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }
    
    return $self->SUPER::cmd($cmd, @_);
}


sub alias {
    my ($alias, $cmd) = @_;

    if (exists $actions{$cmd}) {
	$actions{$alias} = $actions{$cmd};
	return 1;
    }
    return 0;
}

$actions{'reply'} = sub {
    my $self = shift;

    if ($last) {
	return $last->activate() unless ($last eq $self);

	my $l = PSYCion::MultiScreen::Room::current();
	if ($l) {
	    return $l->activate();
	}
    }
};

1;
