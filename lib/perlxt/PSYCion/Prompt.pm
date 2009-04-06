package PSYCion::Prompt;

# implements a generic prompt ... inserts all escape sequences for character 
# movement... 
use strict;
my %actions;

sub curs_pos {
    my $self = shift;

    return (length($self->{'prompt'}) + $self->{'cursor_pos'} - $self->{'print_pos'});
}

sub new {
    my $class = shift;
    my $vars = {
	'prompt' => $_[0]->{'prompt'}||'',
	'data' => '', # data
	'cursor_pos' => 0, #cursor position in the data!!!!
	'print_pos' => 0, # first character to be printed, 0-indexed
	'history' => [''], #history
	'history_pos' => 0, #pos of current history.. scalar(hist) means none 
	'width' => 80,
    };
    
    return bless $vars, $class;
}

sub resize {
    my $self = shift;
    my ($rows, $cols) = @_;
    $self->{'width'} = $cols;
}

sub setPrompt {
#   my $self = shift;
#   $self->{'prompt'} = shift;
    my $me = shift;
    $$me{prompt} = shift;
}

sub hist_down {
    my ($self, $num) = @_;
    my $new_pos;
    $num ||= 1;
    if ($self->{'history_pos'} + $num + 1 > scalar(@{$self->{'history'}})) {
	$new_pos = scalar(@{$self->{'history'}}) - 1;
    } else {
	$new_pos = $self->{'history_pos'} + $num;
    }
    return $self->prompt() if ($new_pos == $self->{'history_pos'});
    $self->{'history_pos'} = $new_pos;
    $self->{'data'} = $self->{'history'}->[$self->{'history_pos'}];
    return $self->reset();    
}

sub hist_up {
    my ($self, $num) = @_;
    $num ||= 1;
    my $new_pos;
    if ($self->{'history_pos'} + 1 == scalar(@{$self->{'history'}})) {
	$self->{'history'}->[$self->{'history_pos'}] = $self->{'data'};
    }
    if ($self->{'history_pos'} - $num <= 0) {
	$new_pos = 0;
    } else {
	$new_pos = $self->{'history_pos'} - $num;
    }
    return $self->prompt() if ($new_pos == $self->{'history_pos'});
    $self->{'history_pos'} = $new_pos;
    $self->{'data'} = $self->{'history'}->[$self->{'history_pos'}];
    return $self->reset();    
}

sub reset {
    my $self = shift;
    my $new_pos = shift;
    $new_pos = length($self->{'data'}) unless (defined($new_pos));
    $self->{'cursor_pos'} = $new_pos;
    $self->{'print_pos'} = $self->{'cursor_pos'} - $self->{'width'} + length($self->{'prompt'}) + 1;
    if ($self->{'print_pos'} < 0) {
	$self->{'print_pos'} = 0;
    }
    return $self->prompt();
}

sub put {
    my ($self, $chars) = @_;

    $chars =~ s/\e\[\d+\~|\e\e\[\w|\e.//g;
    return '' if ($chars eq '');

    for (my $i = 0; $i < length($chars); $i++) {

	if (ord(substr($chars, $i, 1)) >= 32) {
	    next;
	} else {
	    substr($chars, $i, 1, '');
	    return unless length($chars);
	}
    }
    if ($self->{'cursor_pos'} == length($self->{'data'})) {
	$self->{'data'} .= $chars;
	$self->{'cursor_pos'} = length($self->{'data'});
#	return $chars;
    } else {
	$self->{'data'} = substr($self->{'data'}, 0, $self->{'cursor_pos'}).
			    $chars.
			    substr($self->{'data'}, $self->{'cursor_pos'});
	$self->{'cursor_pos'} += length($chars);
    }
    if ($self->{'cursor_pos'} - $self->{'width'} + length($self->{'prompt'}) > $self->{'print_pos'}) {
	$self->{'print_pos'} = $self->{'cursor_pos'} - $self->{'width'} + length($self->{'prompt'});
    }
    $self->{'print_pos'}++ if ($self->{'cursor_pos'} - $self->{'print_pos'} + length($self->{'prompt'}) == $self->{'width'});
    return $self->prompt() if defined(wantarray);
}

#returns the prompt and stores it to the hist...
sub Ret {
    my $self = shift;
    
    if ($self->{'data'} ne $self->{'history'}->[-2]) {
	$self->{'history'}->[-1] = $self->{'data'};
	push(@{$self->{'history'}}, '');
    }
    $self->{'history_pos'} = $#{$self->{'history'}};
    $self->{'data'} = '';
    return $self->reset();
}

sub cursor_left {
    my ($self, $num) = @_;
    $num ||= 1;
    if ($self->{'cursor_pos'} - $num < 0) {
	$num = $self->{'cursor_pos'};
    }
    return '' unless($num);
    $self->{'cursor_pos'} -= $num;
    
    if ($self->{'print_pos'} > $self->{'cursor_pos'}) {
	$self->{'print_pos'} = $self->{'cursor_pos'};
	return $self->prompt(); # we need to redraw!
    }
}

sub cursor_right {
    my ($self, $num) = @_;
    $num ||= 1;
    
    if ($self->{'cursor_pos'} + $num > length($self->{'data'})) {
	$num = length($self->{'data'}) - $self->{'cursor_pos'};	
    }
    return '' unless ($num);
    $self->{'cursor_pos'} += $num;
    if ($self->{'print_pos'} < $self->{'cursor_pos'} - $self->{'width'} + length($self->{'prompt'}) + 1) {
	$self->{'print_pos'} = $self->{'cursor_pos'} - $self->{'width'} + length($self->{'prompt'}) + 1;
	return $self->prompt(); # we need to redraw!
    }
}

sub prompt { 
    my $self = shift;
    my $p_pos = $self->{'print_pos'};
    my $prompt = $self->{'prompt'};
    my $data = $self->{'data'};
    
    my $num = ($self->{'width'} - length($prompt));
    #trim the chars if neseccary
    if ($num + $p_pos >= length($self->{'data'})) {
	$num = length($self->{'data'}) - $p_pos;
    }
    return $prompt.substr($self->{'data'}, $p_pos, $num);
}

sub hist_clear {
    my $self = shift;
    $self->{'history'} = [];
}

sub data {
    my $self = shift;
    my $data = shift;
    $self->{'data'} = $data if (defined($data));
    return $self->{'data'};
}

# offset is a offset in integers.. 
# negative means offset chars left from the cursor
# positive ...
sub current_char {
    my ($self, $offset) = @_;
    $offset = 0 unless (defined($offset));
    
    if ($self->{'cursor_pos'} + $offset < 0
    || $self->{'cursor_pos'} + $offset > length($self->{'data'}) - 1) {
	return '';
    }
    return substr($self->{'data'}, $self->{'cursor_pos'} + $offset, 1);
}

sub cut_tail {
    my $self = shift;
    
    if ($self->{'cursor_pos'} == 0) {
	$self->{'data'} = '';
	return $self->reset();
    }
    
    $self->{'data'} = substr($self->{'data'}, 0, $self->{'cursor_pos'}--);
    $self->reset();
}

sub replace_current_char {
    my ($self, $offset, $char) = @_;
    $offset = 0 unless (defined($offset));
    my $length = length($self->{'data'});
    
    return unless ($length);

    if ($self->{'cursor_pos'} == $self->{'print_pos'}) {
	$self->{'print_pos'} -= ($self->{'print_pos'} >= 13) 
				? 13 : $self->{'print_pos'};	
    }
    
    if ($self->{'cursor_pos'} + $offset < 0) {
	return $self->prompt() if defined(wantarray);
	return;
    } elsif ($self->{'cursor_pos'} + $offset >= $length) {
	$offset = $length - 1 - $self->{'cursor_pos'};
    }
    substr($self->{'data'}, $self->{'cursor_pos'} + $offset, 1, $char);

# this seems evil. do we need it?
    if ($self->{'cursor_pos'} > length($self->{'data'})) {
	$self->{'cursor_pos'} = length($self->{'data'});
	return $self->prompt() if defined(wantarray);
	return;
    }
    $self->cursor_left(); # TODO.. is this really good style?
    return $self->prompt() if defined(wantarray);
}

sub current_word {
    my ($self, $offset) = @_;

    if ($self->{'cursor_pos'} + $offset < 0
    || $self->{'cursor_pos'} + $offset > length($self->{'data'}) - 1) {
	return '';
    }
    if (substr($self->{'data'}, 0, 1 + $self->{'cursor_pos'} + $offset) =~ /([^\s]+)$/) {
	return $1;
    }
    return '';
}

sub cmd {
    my $self = shift;
    my $cmd = shift;
    
    if (exists $actions{$cmd} && $actions{$cmd}->($self, @_)) {
	return 1;
    }
    return;
}

%actions = (
'up-history' => sub {
    my $self = shift;
    $self->hist_up();
    $self->draw_prompt();
},
'down-history' => sub {
    my $self = shift;
    $self->hist_down();
    $self->draw_prompt();
},
'kill-line' => sub {
    my $self = shift;
    $self->cut_tail();
    $self->draw_prompt();
},
'delete-char' => sub {
    my $self = shift;
    if ($self->{cursor_pos} == 0) {
	$self->replace_current_char(0, '');
    } else {
	$self->replace_current_char(0, '');
	$self->cursor_right();
    }
    $self->draw_prompt();
},
'backward-delete-char' => sub {
    my $self = shift;
    $self->replace_current_char(-1, '');
    $self->draw_prompt();
},
'forward-char' => sub {
    my $self = shift;
    $self->cursor_right();
    $self->draw_prompt();
},
'backward-char' => sub {
    my $self = shift;
    $self->cursor_left();
    $self->draw_prompt();
},
'beginning-of-line' => sub {
    my $self = shift;
    $self->reset(0);
    $self->draw_prompt();
},
'end-of-line' => sub {
    my $self = shift;
    $self->reset();
    $self->draw_prompt();
},
'kill-whole-line' => sub {
    my $self = shift;
    $self->data('');
    $self->reset();
    $self->draw_prompt();
},
);

1;
