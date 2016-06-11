package PSYCion::Window;

use strict;
use PSYCion::Prompt;
use base 'PSYCion::Prompt';

my ($last, $current, @windows, %windows, %actions);

sub windows {
    if (exists $_[0]) {
	return $windows{$_[0]} if (exists $windows{$_[0]});
	return $windows[int($_[0])];
    }
    @windows; 
}
sub current { $current }
# last active
sub last { $last }

# next/prev in @windows 
sub next_window { $windows[($_[0]->{'id'} + 1) % @windows] }
sub prev_window { $windows[($_[0]->{'id'} - 1) % @windows] }

sub new {
    my ($class, $name, $silent) = @_;
    my $me = PSYCion::Prompt::new($class, { prompt => $name.'> ' });

    $$me{name} = $name;
    $$me{silent} = $silent;
    
    push(@windows, $me);
    $$me{id} = $#windows;
    
    unless ($current) {
	$current = $me;
    }

    $windows{$name} = $me;
    $me;
}

sub activate {
    my $self = shift;

    unless (ref $self) {
	if (exists $windows{$self}) {
	    $self = $windows{$self};
	} else {
	    my $t = int($self);
	    if ($self eq "$t" && exists $windows[$t]) {
		$self = $windows[$t];
	    } else {
		return 0;
	    }
	}
    }

    $current->deactivate() if ($self ne $current);
    $current = $self;
    
    return 1;
}

sub deactivate {
    my $self = shift;
    $last = $self if (exists $windows{$self->{'name'}});
}

sub remove {
    my $self = shift; 


    if ($self->{'id'} >= 0) {
	foreach ($self->{'id'} + 1 .. $#windows) {
	    $windows[$_]->{'id'}--;
	}
	splice(@windows, $self->{'id'}, 1);
    }

    Net::PSYC::Client::unregister_context($self->{'uni'});
    delete $windows{$self->{'name'}};

    if ($current eq $self) {
	if ($last && $last ne $self) {
	    $last->activate();
	} else {
	    unless ($#windows) {
		$current = 0;
		return 1;
	    }
	    $self->next_window()->activate();
	}
    } elsif ($last eq $current) {
	$last = 0;
    }
    return 1;
}

sub cmd {
    my $self = shift;
    my $cmd = shift;
    
    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }
    return $self->SUPER::cmd($cmd, @_);
}

%actions = (
'reply' => sub {
    return unless (%PSYCion::Person::);
    my $self = shift;

    my $n = PSYCion::Person::reply();

    return unless ($n);

    if ($self eq $n) {
	$n = PSYCion::Window::last();
    }

    # maybe this should be done in PSYCion::Window and PSYCion::Prompt...
    my $d = $self->data();
    $self->data('');
    $n->data($d);
    $n->reset();
    $n->activate();
    $n->draw_window();
},
'remove' => sub {
    my $self = shift;
    $self->remove();
},
'forward-window' => sub {
    my $self = shift;
    my $d = $self->data();
    my $n = $self->next_window();

    $self->data('');
    $n->data($d);
    $n->reset();
    $n->activate();
    $n->draw_window();
},
'backward-window' => sub {
    my $self = shift;
    my $d = $self->data();
    my $n = $self->prev_window();

    $self->data('');
    $n->data($d);
    $n->reset();
    $n->activate();
    $n->draw_window();
},
);
1;
