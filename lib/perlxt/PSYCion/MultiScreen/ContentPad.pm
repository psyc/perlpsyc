package PSYCion::MultiScreen::ContentPad;

use Curses;
use strict;
use warnings 'all';

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

sub new {
    my $class = shift;

    my $self = {};
    $self->{'width'} = shift;
    $self->{'height'} = shift;
    $self->{'pad'} = newpad($self->{'height'}, $self->{'width'});
    $self->{'pad'}->scrollok(1);
    $self->{'c'} = [];
    $self->{'cc'} = {}; 

    $self->{'first'} = 0; # message at the top
    $self->{'last'} = 0;  # message at the bottom
    $self->{'dist'} = 0;  # distance in actual lines
    $self->{'new'} = 0; 	# new messages to be printed in next draw()
    $self->{'new_lines'} = 0; 	# ^^ same in lines
    $self->{'amount'} = 0;# = scalar(@{$self->{'c'}});
    $self->{'lock'} = 0;  # position is locked by scrolling. means that 
			  # new messages dont lead to an actual movement of
			  # the screen
			  # TODO: optional unlock on input
			  # TODO: optional unlock on output

    return bless $self, $class;
}

sub MIN { ($_[0] > $_[1]) ? $_[1] : $_[0] }
sub MAX { ($_[0] > $_[1]) ? $_[0] : $_[1] }
sub ROWS { int($_[0]/$_[1]) + (($_[0] % $_[1]) ? 1 : 0); } 
# lines occupied by N chars on a line of length M

sub out {
    my $self = shift;
    my ($mc, $data, $vars) = @_;

    my ($d, $length) = PSYCion::Main::render($mc, $data, $vars);

    push(@{$self->{'c'}}, [ $d, $length ]);

    $self->{'new_lines'} += ROWS($length, $self->{'width'});
    $self->{'dist'} += ROWS($length, $self->{'width'});
    $self->{'new'}++;
    $self->{'amount'}++;

    $self->{'pad'}->scrl(ROWS($length, $self->{'width'}));
    if ($self->{'dist'} - ROWS($self->{'c'}->[$self->{'first'}]->[1], $self->{'width'}) >= $self->{'height'}) {
	$self->{'first'}++;
    }
    $self->{'last'} = length(@{$self->{'c'}});
    $self->pr($d, $self->{'height'} - ROWS($length, $self->{'width'}));
}

sub scroll_down {
    my $self = shift;
    my $dist = shift;

    if ($self->{'dist'} < $self->{'height'}) {
		
    }
}

# prints $data on line $y including linebreaks and returns the new line
sub pr {
    my $self = shift;
    my $data = shift;
    my $y = shift;
    my $maxn = shift;
    my $win = $self->{'pad'};

    my $x = 0;

    foreach (@$data) {
	if (ref $_) {
	    my $color = COLOR_PAIR($colors{$_->[0]} * 8 + $colors{$_->[1]});
	    $color |= $decoration{$_->[2]} if ($decoration{$_->[2]});
	    $win->attrset($color);
	    next;
	}
	my $offset = 0; #offset _in_ $_
	while ($x + length($_) - $offset > $self->{'width'}) {
	    my $del = $self->{'width'} - $x;	
	    if ($y >= 0 && $y < $self->{'height'}) {
		$win->clrtoeol($y, 0) unless $x;
		$win->addstr($y, $x, substr($_, $offset, $del));
	    }
	    $y++;
	    return $y if (defined($maxn) && --$maxn == 0);
	    $offset += $del;
	    $x = 0;
	}

	if ($y >= 0 && $y < $self->{'height'}) {
	    $win->clrtoeol($y, 0) unless $x;
	    $win->addstr($y, $x, substr($_, $offset));
	}

	$x += length($_) - $offset;
    }
    return $y + 1;
}


