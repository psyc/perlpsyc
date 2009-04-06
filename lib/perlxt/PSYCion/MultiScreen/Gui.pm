package PSYCion::MultiScreen::Gui;

use Net::PSYC::Client qw(UNI sendmsg);
use PSYCion::Main;
use PSYCion::MultiScreen::StatusPad;
use PSYCion::MultiScreen::ContentPad;
use strict;
use Curses;
use base 'PSYCion::Window';

my (%cmd, %guis, $c_init);

my ($slit_offset, $slit_id, $slit_changed) = (0, 0, 1);
my (@slit, %metrices, @slit_cache);

my %colors = (
    'black' => 0,
    'red' => 1,
    'green' => 2,
    'yellow' => 3,
    'blue' => 4,
    'magenta' => 5,
    'cyan' => 6,
    'white' => 7,
    'dark' => 0,
);

my %decoration = (
    'bold' => A_BOLD(),
    'blink' => A_BLINK(),
    'reverse' => A_REVERSE(),
    'underline' => A_UNDERLINE(),
);

sub c_init {
    start_color();
    foreach (0..64) {
	init_pair($_, $_ % 8, int($_/8));
    }
    $c_init = 1;
}

sub min {
    ($_[0] > $_[1]) ? $_[1] : $_[0]
}
sub sign { ($_[0] < 0) ? -1 : 1 }

# used by the slit
sub name {
    my $self = shift;
    return ($self->{'name'}, $self->{'color'});
}

sub scroll_bar {
    my ($length, $total, $offset, $part) = @_; 
    my ($t, $c, @string);

    $c = $length;
    $t = int($offset/$total * $length) if ($offset != 0);
    
    if ($t) {
	$t-- if ($t == $length);
	push(@string, PSYCion::Main::get_color('_scrollbar_background'), chr(160) x $t);
    }
    $c -= $t;
    
    $t = int($part/$total * $length); 
    $t = 1 unless ($t);
    push(@string, PSYCion::Main::get_color('_scrollbar'), chr(160) x $t);
    $c -= $t;

    push(@string, PSYCion::Main::get_color('_scrollbar_background'), chr(160) x $c) if ($c);
    
    return \@string;
}


#######
# SLIT
# .. when someone starts to make these comment-seperators in perl, its usually
# time to split it up into different modules.

# calculates a timestep in ] 0.0, 0.25 ].
# TODO ... think about that 
sub time_step {
    my $dist = abs(shift);
    
    return 0.25 if ($dist < 1);
    return 0.25/$dist;
}

# do one animation step...
sub move {
    if (abs($slit_offset) < 1) {
	$slit_offset = 0;
    } else {
	$slit_offset -= sign($slit_offset);
	Net::PSYC::Event::add(time_step($slit_offset), 't', \&move);
    }

    $slit_changed = 1;
    return PSYCion::Window::current()->draw_prompt();
}

sub status_line {
    my $self = shift;
    my $width = shift;

    [PSYCion::Main::get_color('_status'), ' ' x $width ];
}

sub slit_name {
    my $self = shift;

    if ($self->{'changes'}) {
	my @anim = ('o', '.', 'o', 'O');
	return " $self->{'name'}\[".$anim[$self->{'changes'} % scalar(@anim)]."] ";
    }
    return " $self->{'name'}\[ ] ";
}

sub slit {
    my ($t, $base, $width) = ($slit_offset, scalar(@slit), COLS() - 4);
    my ($left_chars, $right_chars, $right_id);

    # search for the element to draw in the middle
    # the question is: does this allways terminate
    return \@slit_cache unless ($slit_changed);
    $slit_changed = 0;
    
    my $left_id = 2 * $slit_id;

    unless ($slit[$left_id+1]) {
	use Data::Dumper;
	Net::PSYC::W0("A window disappeared: %s\n", join("", Dumper(@slit)));
	return \@slit_cache;
    }

    if (abs($t) > length($slit[$left_id+1]->slit_name())/2) {
	my $sgn = sign($slit_offset);
	my $len = length($slit[$left_id+1]->slit_name())/2;
	$left_id = ($left_id + $sgn*2) % $base;
	$t -= $sgn*$len;

	while (1) {
	    $len = length($slit[$left_id+1]->slit_name());
	    if (abs($t) <= $len) {
		if ($slit_offset < 0) {
		    $t += $len/2;
		} else {
		    $t -= $len/2;
		}
		last;
	    }
	    # possibilities:
	    #  t < 0
	    #  	|t| < len/2 : t = len/2 + t
	    #   |t| > len/2 : t = t + len/2
	    #  t > 0
	    #   |t| < len/2 : t = - (len/2 - t)
	    #   |t| > len/2 : t = t - len/2
	    $left_id = ($left_id + $sgn*2) % $base;
	    $t -= $sgn*$len;
	}
    }
    $right_chars -= $t;
    $left_chars += $t;

    $t = length($slit[$left_id + 1]->slit_name());
    $right_chars += $t/2;
    $left_chars += $t/2;

    @slit_cache = ($slit[$left_id], $slit[$left_id + 1]->slit_name());
    $right_id = ($left_id + 2) % $base;
    $left_id = ($left_id - 2) % $base;
    # hope this works ,)

    while ($right_chars + $left_chars < $width) {
	my $len;
	if ($right_chars > $left_chars) {
	    $len = length($slit[$left_id+1]->slit_name());
	    $metrices{$left_id/2} = -1;
	    
	    if ($len + $left_chars > $width/2) {
		$len = int($width/2- $left_chars);
		my $n = $slit[$left_id + 1]->slit_name();
		unshift(@slit_cache, $slit[$left_id], 
				     substr($n, length($n) - $len));
	    } else {
		unshift(@slit_cache, $slit[$left_id], 
				     $slit[$left_id + 1]->slit_name());
	    }
	    $left_chars += $len;
	    last if ($right_id == $left_id);
	    $left_id = ($left_id - 2) % $base;
	} else {
	    $len = length($slit[$right_id+1]->slit_name());
	    $metrices{$right_id/2} = 1;

	    if ($len + $right_chars > $width/2) {
		$len = int($width/2 - $right_chars);
		push(@slit_cache, $slit[$right_id],
			       substr($slit[$right_id + 1]->slit_name(), 0, $len));
	    } else {
		push(@slit_cache, $slit[$right_id], $slit[$right_id + 1]->slit_name());
	    }
	    $right_chars += $len;
	    last if ($right_id == $left_id);
	    $right_id = ($right_id + 2) % $base;
	}
    }
    $left_chars = $width/2 - $left_chars;
    $right_chars = $width/2 - $right_chars;

    if ($left_chars != int($left_chars)) {
	if ($left_chars - int($left_chars) > $right_chars - int($right_chars)) {
	    $left_chars = int($left_chars + 1);
	    $right_chars = int($right_chars);
	} elsif ($left_chars - int($left_chars) == $right_chars - int($right_chars)) {
	    if ($slit_offset > 0) { # moving left 
		$left_chars = int($left_chars + 1);
		$right_chars = int($right_chars);
	    } else {
		$left_chars = int($left_chars);
		$right_chars = int($right_chars + 1);
	    }
	} else {
	    $left_chars = int($left_chars);
	    $right_chars = int($right_chars + 1);
	}
    }
    
    push(@slit_cache, PSYCion::Main::get_color('_status'), ' ' x $right_chars, ' >');
    unshift(@slit_cache, PSYCion::Main::get_color('_status'), '< ', ' ' x $left_chars);

    \@slit_cache;
}

sub resize {
    my $self = shift;
    my ($rows, $cols) = @_;

    $slit_changed = 1;

    $self->{'content_cache'} = {};
    $self->{'changes'} = 1;
}

sub new {
    my $self = PSYCion::Window::new(@_);
    $self->{'w'} = new Curses;
    $self->{'w'}->idlok(1);

    $self->{'pad_content'} = 
	new PSYCion::MultiScreen::ContentPad(COLS(), LINES() - 1);
    $self->{'pad_status'} = 
	new PSYCion::MultiScreen::StatusPad(COLS(), int(LINES()/2) - 1); 	
    

    use Storable qw(dclone);
    $self->{'color'} = dclone(PSYCion::Main::get_color('_status'));
    c_init() unless ($c_init);
    push(@slit, $self->{'color'}, $self);
    $slit_changed = 1;
    $metrices{$self->{'id'}} = 1;

    return $self;
}

sub out {
    my $self = shift;
    my ($mc, $data, $vars) = @_;

    if ($self ne PSYCion::Window::current()) {
	$slit_changed = 1;
    }
    
    if (is_status($mc)) {
	foreach (split(/\r?\n/, $data)) {
	    $self->{'pad_status'}->out($mc, $_, $vars);
	}
    } else {
	foreach (split(/\r?\n/, $data)) {
	    $self->{'pad_content'}->out($mc, $_, $vars);
	}
    }
    $self->{'changes'}++;

    if (PSYCion::Window::current() eq $self) {
	$self->draw_window();
    }
}

sub is_status {
    $_[0] =~ /^(?:_status|_notice_update_cvs|_notice_place_examine)/;
}

sub draw_window {
    my $self = shift;

    $self->draw_content();
    $self->draw_prompt();
}

sub draw_content {
    my $self = shift;

    my $n = $self->{'pad_status'}->draw();
    $self->{'pad_status'}->{'pad'}->
	prefresh(0, 0, 
		 0, 0, 
		 $n-1, COLS()) if $n;
    $self->{'pad_content'}->{'pad'}->
	prefresh($n+1, 0, 
		 $n+1, 0, 
		 LINES(), COLS());
=man
int prefresh(WINDOW *pad, int pminrow, int pmincol,
             int sminrow, int smincol, int smaxrow, int smaxcol);
=cut
    return 1;
}

sub draw_prompt {
    my $self = shift;
    my $win = stdscr();
    my $height = LINES();
    
    $win->clrtoeol($height - 1, 0);
    $win->addstr($height - 1, 0, $self->prompt());
    $win->move($height - 1, $self->curs_pos());
    $win->refresh();
}

sub deactivate {
    my $self = shift;

    $self->{'color'}->[2] = '';
    $self->SUPER::deactivate();
}

sub activate {
    my $self = shift;
    my $last = PSYCion::Window::current(); 

    if ($self ne PSYCion::Window::current()) {
	$self->{'changes'}++;
	$slit_changed = 1;
    }

    unless ($self eq $last) {
	$self->{'color'}->[2] = 'bold';
	
	$slit_changed = 1;
	$self->SUPER::activate();
	#TODO: curs_refresh: redrawwin
	$self->draw_window();
	Net::PSYC::Event::add(0.25, 't', \&move) unless ($slit_offset);
	$slit_offset -= metric($last->{'id'}, $self->{'id'});
	$slit_id = $self->{'id'};
    } else {
	$self->SUPER::activate();
    }
    
    sub metric {
	# will calculate le distance minimal (in string length), 
	# left - or right-way
	my ($l, $a, $b, $len);
	my $mod = scalar(@slit);
	$a = $_[0] * 2;
	$len = length($slit[$a+1]->slit_name())/2;
	$b = $_[1] * 2;
	while ($a != $b) {
	    $l += $len;
	    $a = ($a + 2*$metrices{$_[1]}) % $mod;
	    $len = length($slit[$a+1]->slit_name())/2;
	    $l = $l + $len;
	}
	return $l*$metrices{$_[1]};
    }
}

sub remove {
    my $self = shift;

    $self->SUPER::remove();
    splice(@slit, $self->{'id'}*2, 2);
    delete $metrices{$self->{'id'}};
}

sub cmd {
    my $self = shift;
    my $cmd = shift;

    if (exists $cmd{$cmd} && $cmd{$cmd}->($self, @_)) {
	return 1;
    }
    $self->SUPER::cmd($cmd, @_);
}

%cmd = (
'info' => sub {
    my $self = shift;
    use Data::Dumper qw(Dumper);
    $Data::Dumper::Maxdepth = 1;
    my $s = join("", Dumper($self));
    $s =~ s/\t/  /g;
    
    $self->out('_ION_debug', $s);
},
'debug' => sub {
    shift;
    my $level = shift;
    Net::PSYC::setDEBUG(int($level));
},
'remove' => sub {
    my $self = shift;

    $self->remove();
},
'submit' => sub {
    my $self = shift;
    my $d = $self->data();

    if ($d eq '') {
	if ($self->{'status_changes'}) {
	    $self->{'status_changes'} -= min($self->{'status_changes'}, 
					    $self->{'status_displayed'});
	    $self->{'changes'} = 1;
	    $self->draw_window();
	    return 1;
	}
	return 1;	
    }

    $self->Ret();

    if ($d =~ /^\//) {
	$d = substr($d, 1);
	unless ($self->cmd(split(/\s/, $d))) {
	    $self->cmd('execute', $d);
	}
    } else {
	$self->cmd('say', $d);
    }

    $self->draw_window();
},
'execute' => sub {
    my $self = shift;
    my $data = shift;
    sendmsg(UNI(), '_request_execute', $data);
},
'scroll-up' => sub {
},
'scroll-down' => sub {
},
'clear-screen' => sub {
    my $self = shift;
},
);

1;
