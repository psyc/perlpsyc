package PSYCion::SingleScreen::Gui;

use base 'PSYCion::Window';

my %actions = (
'info' => sub {
    my $self = shift;
    $self->out('_ION_info', "uni: [_uni]\nname: [_name]",
		{
		    _uni => $self->{'uni'},
		    _name => $self->{'name'},
		});
},
'submit' => sub {
    my $self = shift;
    my $d = $self->data();

    if ($d eq '') {
	$self->del_screen();
	$self->draw_prompt();
	return 1;
    }

    $self->Ret();

    if ($d =~ /^\//) {
	$d = substr($d, 1);

	unless (PSYCion::Main::cmd(split(/\s/, $d))) {
	    PSYCion::Main::cmd('execute', $d);
	}
    } else {
	$self->cmd('say', $d);
    }
    $self->draw_prompt();
},
);

sub cmd {
    my $self = shift;
    my $cmd = shift;

    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }
    $self->SUPER::cmd($cmd, @_);
}

sub new {
    my $self = PSYCion::Window::new(@_);
    $self;
}
sub del_screen {
    PSYCion::SingleScreen::del_screen();
}

sub del_line {
    PSYCion::SingleScreen::del_line();
}

sub new_line {
    PSYCion::SingleScreen::new_line();
}

sub draw_prompt {
    my $self = shift;
    PSYCion::SingleScreen::draw_prompt();
    $self;
}

*draw_window = *draw_prompt;

sub output {
    my $self = shift;
    PSYCion::SingleScreen::output(@_);
    $self;
}

sub out {
    my $self = shift;
    PSYCion::SingleScreen::out(@_);
    $self;
}


1;
