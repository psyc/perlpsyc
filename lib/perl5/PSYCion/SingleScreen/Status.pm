package PSYCion::SingleScreen::Status;

use strict;

use Net::PSYC::Client qw(sendmsg);
use Net::PSYC qw(psyctext);
use PSYCion::Status;

use base 'PSYCion::SingleScreen::Gui';

sub new {
    my $class = shift;
    my $uni = shift;
    my $name = shift;
    my $v = PSYCion::SingleScreen::Gui::new($class, $name);
    $v->{'uni'} = $uni;
    $v->{'name'} = $name;
    $v->{'type'} = 'status';
    $v->{'buffer'} = [];
    $v;
}

sub msg {
    # this msg handler is only used during login
    my ($self, $source, $mc, $data, $vars) = @_;
    $self->out($mc, $data, $vars);
    if ($mc =~ /^_notice_unlink/
    ||  $mc eq '_error_invalid_password'
    ||  $mc eq '_echo_logoff') {
	print "\r";
	exit();
    }
}

sub status {
    my $self = shift;
    sendmsg($self->{'uni'},'_request_description');
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
