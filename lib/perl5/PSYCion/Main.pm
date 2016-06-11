package PSYCion::Main;

use strict;
use Net::PSYC::Tie::AbbrevHash;

use base 'Exporter';

my (%method_colors, %var_colors, %templates, $ckeys, @complete, @tkeys, %keys,
    $mode, %match_colors);
our ($no_color, %actions);
our @EXPORT = qw(%actions);
%method_colors = ();
%var_colors = ();
%templates = ();
%keys = ();
$ckeys = \%keys;
tie %method_colors,'Net::PSYC::Tie::AbbrevHash';
tie %var_colors, 'Net::PSYC::Tie::AbbrevHash';
tie %templates, 'Net::PSYC::Tie::AbbrevHash';

sub getTemplate {
    return $templates{$_[0]};
}

sub checkColor {
    my $colors = shift;
    my @c = ('','','');
    # we do onjy accept special colors.. wui
    foreach (('red','green','yellow','blue','black','dark','magenta','cyan',
	      'white')) {
	if ($colors =~ /^$_|\s$_/i) {
	    $c[1] = $_;
	    #push(@c, $_);
	    last;
	}
    }
    foreach (('on_red','on_green','on_yellow','on_blue','on_white',
	     'on_black','on_dark','on_magenta','on_cyan')) {
	if ($colors =~ /$_/i) {
	    $c[0] = substr($_, 3);
	    #push(@c, $_);
	    last;
	}
    }
    foreach (('bold', 'underline', 'underscore', 'blink', 'reverse', 
	      'concealed')) {
	if ($colors =~ /$_/i) {
	    $c[2] = $_;
	    #push(@c, $_);
	    last;
	}
    }
    return \@c;
}

sub get_color {
    my $color = shift;

    if (exists $method_colors{'_ION'.$color}) {
	return $method_colors{'_ION'.$color};
    } elsif (exists $method_colors{'_ION_default'}) {
	return $method_colors{'_ION_default'};
    }
    return ['black', 'white', ''];
} 

sub type {
    my $c = -1;

    # chars
    foreach (@_) {
	$c++;
	unless (exists $ckeys->{$_}) {
	    if ($ckeys eq \%keys) { 
		input($_); 
	    } else {
		my $key = ($c + 1 == $#_) ? join(@tkeys, '').$_.$_[$#_]
					  : join(@tkeys, '').$_;
		out('_ION_warn', '[_key] is not bound to a command!', 
			{ _key => get_key_name($key) });
	    }
	} elsif (ref $ckeys->{$_} eq 'HASH') {
	    #we need to check for the end of @_ to avoid <ESC> cancel everything
	    #else..
	    if (exists $ckeys->{$_}->{$mode} && $c == $#_) {
		my $action = $ckeys->{$_}->{$mode};
		if (ref $action eq 'ARRAY') {
		    cmd(@$action);
		} else {
		    cmd($action);
		}
	    } else {
		push(@tkeys, $_);
		$ckeys = $ckeys->{$_};
		next;
	    }
	}
	$ckeys = \%keys;
	@tkeys = ();
    }
}

sub get_key_name {
    my $key = shift;
    
    return unpack("h*", $key);
}

sub gkey {
    my $name = shift;

    return "\e" if ($name =~ /esc/i);
    return "\t" if ($name =~ /tab/i);
    return "\x7f" if ($name =~ /bs/i);

    my $key;
    my ($ctrl, $alt) = ("(?:c-|ctr?l?-)", "(?:alt-|a-)");

    if ($name =~ /$ctrl$alt(\w)|$alt$ctrl(\w)|\^\[\.(\w)/i) {
	$key = ord(lc($1)) - 96;
	return ("\e", chr($key));	
    } elsif ($name =~ /$alt(\w)|^\[(\w)/i) { # alt
	return ("\e", $1);
    } elsif ($name =~ /$ctrl(\w)|\^(\w)/i) {
	return chr(ord(lc($1)) - 96);
    }

    return ();
}

sub parse_line {
    my $line = shift;
    my $dir = shift;
    if ($line =~ /^mark\s+([\w_]+)\s+([\w_]+)\s+(\S.+)$/) {
	my $color = $3;
	my $match = $2;
	my $type = $1;
	$color = checkColor($color);

	unless ($color) {
	    return "$3 is no valid color. (in '$&')";
	}

	if ($type =~ /method|mc/) {
	    if ((exists $method_colors{$match}) < 0) {
		my $c = $method_colors{$match};
		# we give around references. this allows us to change this by
		# a "magische fernwirkung"
		$c->[0] = $color->[0];
		$c->[1] = $color->[1];
		$c->[2] = $color->[2];
	    } else {
		$method_colors{$match} = $color; 
	    }
	} elsif ($type =~ /variable|var/) {
	    if ((exists $var_colors{$match}) < 0) {
		my $c = $var_colors{$match};
		# we give around references. this allows us to change this by
		# a "magische fernwirkung"
		$c->[0] = $color->[0];
		$c->[1] = $color->[1];
		$c->[2] = $color->[2];
	    } else {
		$var_colors{$match} = $color; 
	    }
	} elsif ($type =~ /(ignorec|c)ase/) {
	    my $re;
	    if ($1 eq 'c') {
		$re = eval{ qr/$match/o };
	    } else {
		$re = eval{ qr/$match/oi };
	    }
	    unless ($re) {
		return "$2 is no valid regexp. (in 'mark $type $match $color')";
	    }
	    $match_colors{$re} = $color;
	}
    } elsif ($line =~ /^template\s+([\w_]+)\s+(\S[^\n\r]*)/) {
	$templates{$1} = $2;
    } elsif ($line =~ /^complete\s+(\S.+)$/) {
	push(@complete, split(/\s+/, $1));
    # attempt to become compatible to the tcsh bindkey syntax
    } elsif ($line =~ /^bin(?:d|dkey)\s+(\S+)\s+\&?([^\s\(\)]+)(?:\(([^\)]*)\))?/) {
	my (@params, $mode, $k, $action);
	$action = $2;
	$k = $1;

	if ($3) {
	    @params = split(/,\s?/, $3);
	    foreach (@params) {
		if (/^\"(.*)\"$/) {
		    $_ = $1;
		} elsif (/^-?\d+$/) {
		    $_ = int($_);
		}
	    }
	    $action = [$action, @params];
	}

	if ($k =~ /^\w{2,}::/) {
	    ($mode, $k) = split(/::/, $k);
	}
	my $keys = \%keys;
	my $temp;
	my $print;
	while (length($k)) {
	    $keys = $keys->{$temp} if $temp;

	    if ($k =~ s/^\<([^\<]+)\>//g) {
		my $pk = $1;
		my @keys = get_key($1);

		unless (@keys) {
		    out('_ION_warn', "Unknown key: <$1>");
		    return;
		}

		if (@keys > 1) {
		    $temp = shift @keys;
		    $k = join('', @keys).$k;
		} else {
		    $temp = $keys[0];
		}
	    } else {
		$temp = substr($k, 0, 1, '');
	    }

	    unless (exists $keys->{$temp} && ref $keys->{$temp}) {
		$keys->{$temp} = {};
	    }

	}

	$mode = '' unless defined($mode);
	$keys->{$temp}->{$mode} = $action;
    } elsif ($line =~ /^load\s+(\S.+)$/) {
	my $file = $1;
	if ($file =~ /^\~/) {
	    substr($file, 0, 1, $ENV{'HOME'});  
	    return load_config($file);
	}
	return load_config($dir.$file);
    } elsif ($line =~ /^alias\s+(\w+)\s+(\w+)$/) {
	unless (alias($1, $2)) {
	    return "No such command '$2'";
	}
    } elsif ($line =~ /\w/) {
	return "Unknown command in '$line'";
    }
    return "Unknown command.";
}

sub load_config {
    my $file = shift;
    my $dir = substr($file, 0, rindex($file, '/')+1);
    my $line;
    if (-e $file) {
	Net::PSYC::W1('Opening config file: %s', $file);
	# I wonder why this did not lead to problems.. 
	local *FILE;
	open(*FILE, '<', $file) or return 0;
	while (defined($line = readline(*FILE))) {
	    parse_line($line, $dir);
	}
	close(*FILE);
	# output *after* loading so the first file can disable its output
        out('_ION_verbose', "absorbed $file");
	return 1;
    }
    return 0;
}

sub render {
    my ($mc, $data, $vars) = @_;
    my $template = getTemplate($mc);
    my $length = 0;

    my $bg = (exists $method_colors{$mc}) 
	     ? merge(get_color('_default'), $method_colors{$mc})
	     : get_color('_default');

    my @wu = ();
    unless ($template) {
	$template = $data;
    } else {
	$template =~ s/\[\?\ (_\w+)\](.+?)\[\;\]/(exists $vars->{$1}) ? $2 : ""/ge;
	$template =~ s/\[\?\ (_\w+)\](.+?)\[\:\](.+?)\[\;\]/(exists $vars->{$1}) ? $2 : $3/ge;
	$template =~ s/\[\!\ (_\w+)\](.+?)\[\;\]/(!exists $vars->{$1}) ? $2 : ""/ge;
	$template =~ s/\[\!\ (_\w+)\](.+?)\[\:\](.+?)\[\;\]/(!exists $vars->{$1}) ? $2 : $3/ge;
	$template =~ s/\[_data\]/$data/ unless $mc =~ /_message|_echo_message/;
	$vars->{'_method'} = $mc;
    }
    while ($template =~ s/^(.*?)\[(_\w+)\]//s) {
	my $s = $1;
	my $v = $2;
	my $c = $var_colors{$v};
	if ($c && exists $vars->{$v}) {
	    $v = var($vars->{$v});
	    $length += length($s)+length($v) if wantarray;
	    push(@wu, $bg, match_color($s), merge($bg, $c), match_color($v));
	} elsif (exists $vars->{$v}) {
	    $v = var($vars->{$v});
	    $length += length($s)+length($v) if wantarray;
	    push(@wu, $bg, match_color($s.$v));
	} else {
	    $length += length($&) if wantarray;
	    push(@wu, $bg, match_color($&));
	}
    }
    if ($template) {
	$length += length($template) if wantarray;
	push(@wu, ($bg, match_color($template)));
    }
    foreach (0..$#wu) {
	next if (ref $wu[$_]);
	$wu[$_] =~ s/\[_data\]/$data/;
    }

    return (\@wu, $length) if wantarray;
    return \@wu;
    sub merge {
	my $a = shift;
	my $b = shift;
	return [
	    $b->[0]||$a->[0],
	    $b->[1]||$a->[1],
	    $b->[2]||$a->[2]
	];
    }
    sub var {
	my $v = shift;
	if (ref $v eq 'ARRAY') {
	    return join(', ', @$v);
	} else {
	    return $v;
	}
    }
    sub match_color {
	my $s = shift;
	$s;		
    }
}

%actions = (
'nothing' => sub {},
'exit' => sub {
    Net::PSYC::Event::stop_loop();
},
'shutdown' => sub {
    Net::PSYC::Client::psycUnlink();
},
'mode' => sub {
    my $self = shift;
    $mode = shift||'';

    if ($mode ne '') {
	$self->out('_ION_info', 'Activated [_mode].',
		   { '_mode' => $mode });
    } else {
	$self->out('_ION_info', 'Deactivated.');
    }
    return 1;
},
);

1;
