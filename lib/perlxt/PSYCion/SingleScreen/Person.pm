package PSYCion::SingleScreen::Person;

use Net::PSYC::Client qw(sendmsg NICK);
use Net::PSYC qw(psyctext);
use PSYCion::Person;
use PSYCion::Prompt;

use strict;
use base 'PSYCion::SingleScreen::Gui';

sub new {
    my $class = shift;
    my $uni = shift;
    my $name = shift;
    my $v = PSYCion::SingleScreen::Gui::new($class,$name);
    $v->{'uni'} = $uni;
    $v->{'name'} = $name;
    $v->{'type'} = 'person';
    PSYCion::Person::set_reply($v);
    $v;
}

sub msg {
    my ($self, $source, $mc, $data, $vars) = @_;
    PSYCion::Person::set_reply($self);
    $self->out($mc, $data, $vars);
}

sub cmd {
    my $self = shift;
    my $cmd = shift;
    
    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }
    
    $self->SUPER::cmd($cmd, @_);
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
