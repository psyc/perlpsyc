package PSYCion::MultiScreen::StatusPad;

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
    $self->{'drawn'} = 0;
    $self->{'undrawn'} = 0;
    $self->{'cleared'} = 0;
    $self->{'scroll'} = 0;
    $self->{'lines'} = 0;

    return bless $self, $class;
}

sub MIN { ($_[0] > $_[1]) ? $_[1] : $_[0] }
sub MAX { ($_[0] > $_[1]) ? $_[0] : $_[1] }
sub ROWS { int($_[0]/$_[1]) + (($_[0] % $_[1]) ? 1 : 0); } 
# lines occupied by N chars on a line of length M

# this method just keeps track of the internal data structure
sub out {
    my $self = shift;
    my ($mc, $data, $vars) = @_;

    my ($d, $length) = (PSYCion::Main::render($mc, $data, $vars));

    push(@{$self->{'c'}}, [ $d, $length ]);

    $self->{'scroll'} += ROWS($length, $self->{'width'});
    $self->{'undrawn'}++;
}

sub draw {
    my $self = shift;
    my $win = $self->{'pad'};

    return MIN($self->{'lines'}, $self->{'height'}) 
	unless ($self->{'undrawn'});


    my $i = scalar(@{$self->{'c'}}) - $self->{'undrawn'};

    my $physical_line;
    $physical_line = MIN($self->{'height'} - 1, $self->{'scroll'} - 1);

    if ($self->{'scroll'} > $self->{'height'}) {
	$win->clear();
    } elsif ($self->{'scroll'}) {
	$win->scrl(-$self->{'scroll'});
    }

    while ($physical_line >= 0 
	&& $physical_line < $self->{'height'} 
	&& $i < scalar(@{$self->{'c'}})) {

	my ($line, $length) = @{ $self->{'c'}->[$i] };
	my $x = 0; # position x to start drawing

	$physical_line -= ROWS($length, $self->{'width'}) - 1;
	$win->clrtoeol($physical_line, 0);

	foreach (@$line) {
	    if (ref $_) {
		my $color = COLOR_PAIR($colors{$_->[0]} * 8 + $colors{$_->[1]});
		$color |= $decoration{$_->[2]} if ($decoration{$_->[2]});
		$win->attrset($color);
		next;
	    }
	    my $offset = 0; #offset _in_ $_
	    while ($x + length($_) - $offset > $self->{'width'}) {
		my $del = $self->{'width'} - $x;	
		unless ($physical_line < 0) {
		    $win->addstr($physical_line, $x, substr($_, $offset, $del));
		}
		$physical_line++;
		$win->clrtoeol($physical_line, 0);
		$offset += $del;
		$x = 0;
	    }
	    if ($offset) {
		$win->addstr($physical_line, $x, substr($_, $offset));
	    } else {
		$win->addstr($physical_line, $x, $_);
	    }
	    $x += length($_) - $offset;
	}
	$physical_line -= ROWS($length, $self->{'width'}) - 1;
	# turn off all attributes
	$win->standend();
	$i++;
	$self->{'undrawn'}--;
	$self->{'drawn'}++;
    }
    $self->{'lines'} += $self->{'scroll'};
    $self->{'scroll'} = 0;
    return MIN($self->{'height'}, $self->{'lines'}); 
}

