package Net::PSYC::MMP::Encoding;
# hook on receive & send and do the encoding... dont know any details yet. 
#
require 5.004;
use strict;
use Encode;

my @p = (
    'ISO-8859-1',
    'UTF-8',
);


sub new {
    my $class = shift;
    my $obj = shift;
    my $lc = $ENV{'LC_LCTYPE'};
    my $self = {
        'connection' => $obj,
	'LC_CTYPE' => $lc,
    };
    if (exists $ENV{'ENCODING'}) {
	# check it first! perhaps with Encode::Supported
    } elsif ($lc && $lc =~ /\.utf8$/) {
	$self->{'system'} = 'UTF-8';	
    } else {
	$self->{'system'} = 'ISO-8859-1';
    }
    return bless $self, $class;
}

sub init {
    my $self = shift;
    $self->{'connection'}->hook('send', $self);
    # do encoding _after_ state
    $self->{'connection'}->hook('receive', $self);
}

sub send {
    my $self = shift;
    my ($vars, $data) = @_;

    if (exists $self->{'out'} && $self->{'system'} ne $self->{'out'}
    &&  !exists $vars->{'_encoding'}) {
	# what about references?? ar!
	$$data = encode($self->{'out'}, $$data);
	foreach (keys %$vars) {
	    $vars->{$_} = encode($self->{'out'}, $$data);
	}
	$vars->{'_encoding'} = $self->{'out'};
    }

}

sub receive {
    my $self = shift;
    my ($vars, $data) = @_;

    if (!exists $self->{'out'}) {
	if (exists $vars->{'_available_characters'}) {
	    my $ac = $vars->{'_available_characters'};
	    if ($ac =~ /$self->{'system'}/i) {
		$self->{'out'} = $self->{'system'};
		goto DONE;
	    }

	    foreach (@p) {
		if ($vars->{'_available_characters'} =~ /$_/) {
		    $self->{'out'} = $_;
		    goto DONE;
		}
	    }
	}
	$self->{'out'} = $self->{'system'};
    }
    DONE:

    if (exists $vars->{'_encoding'} 
    && $vars->{'_encoding'} ne $vars->{'system'}) {
	from_to($vars->{'_encoding'}, $self->{'system'}, $data);

	# check _encoding first.. but for now
	foreach (keys %$vars) {
	    from_to($vars->{'_encoding'}, $self->{'system'}, \${$vars->{$_}});
	}
    }
}


1;
# 
