package MP3::List;

use MP3::Info;

sub format {
	# ugly as hell, how can we fix this?
	my ($local, $full, $opt_z, $opt_x, $opt_v, $opt_h,
	    $opt_D, $opt_p, $opt_E, $opt_n, $opt_b, $opt_L) = @_;
	$full = $local unless $full;
	my ($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_ = $local);
	return unless -f $_;
#	return unless (not $already_seen{"$dev,$ino"}) &&
#	    (($already_seen{"$dev,$ino"} = !(-d _)) || 1);
	return if /\bTRANS\.TBL$/i;
	if ($opt_p) {
	    print "$full\n";
	    return;
	}

	my $sumTime = 0;
	my $output = '';
	my $size = -s _;
	return if $size < 3 && $opt_E;

	$full =~ s!^\./!!;
	$full = "<a href='$full'>$full</a>" if $opt_h;

	unless ($opt_z) {
	    my $info = 0;
# actually it wasn't a filename problem, it's a bug in the ntfs implementation
#		if (/^- /) {
#			print STDERR "\r[failure] illegal filename '$_', please rename.\n";
#			return;
#		} else {
#			print STDERR "get_mp3info <- $_\n";
			$info = get_mp3info($_) if /\.mp\d\b/i;
#			print STDERR "get_mp3info -> $info\n";
#		}
	    unless ($info) {
		    return if $opt_h &&! /\.s?html?$/;
		    return if /\.met$/ or $opt_b;
		    return sprintf("%10d\t\t%7s = %s\r\n", $size, $full,
			&extra_part) if /\b\d+\.part$/;
		    # would be logical if uncompressed audio always
		    # appeared when using -b ... hm!
		    $output = sprintf("%10d\t\t%s\r\n", $size, $full)
		       if !$opt_x or /\.(flac|wav|aiff)\b/i && $size > 6999999;
		    return $output;
	    }
	    if ($opt_v) {
		print "\n", '·' x 70, "\n";
		foreach my $k (sort keys %$info) {
		    printf "%13s %s\n", $k, $info->{$k};
		}
		print "\n";
	    }
	    return if $opt_b > $info->{BITRATE};
	    return ("$full\n", 0) if $opt_L;
	    my $flag = ' ';
	    my $scale;
FLAG:
	    {
		# damaged: apparently incomplete file
		$flag = 'D', last FLAG if abs($size - $info->{SIZE}) > 33333;
		# mono mp3
		$flag = 'm', last FLAG if $info->{MODE} == 3;
		# low frequency (typical for speech recordings)
		$flag = 'F', last FLAG if $info->{FREQUENCY} < 44;
		# abnormal high frequency (48kHz)
		$flag = 'f', last FLAG if $info->{FREQUENCY} > 45;
#
# the VBR scale isn't used consistently by all encoders.. weird!
# and there is no way to tell, it seems.
#
#		if ($scale = $info->{VBR_SCALE}) {
#		    $scale = int 10-$scale/10;
##		    $flag = 'h', last FLAG if $scale < 2;
##		    $flag = 'L', last FLAG if $scale > 7;
#		    if ($scale > 6 and $info->{BITRATE} > 199) {
#			    print STDERR "... WEIIIRD\n\n";
#		    } else {
#			    $flag = $scale, last FLAG;
#		    }
#		}
		# high quality (probably beyond CD requirement)
		$flag = 'H', last FLAG if $info->{BITRATE} > 222;
		$flag = 'v', last FLAG if $info->{VBR} &&
					  $info->{BITRATE} > 109;
		# web download quality (low! but still useful)
		$flag = 'w', last FLAG if $info->{VBR} &&
					  $info->{BITRATE} <= 109;
		# LOW static quality
		$flag = 'L', last FLAG if $info->{BITRATE} < 130;
	    }
	    if ($opt_D && $flag eq 'L') {
		$flag = unlink($_) ? '***' : '???';
	    }
	    $output = $opt_n?
		sprintf("%s%s%10d %5s %3s\t%s\r\n",
		   $nlink > 1 ? $nlink : ' ', $flag,
		   $size,
		   $info->{TIME},
		   $info->{BITRATE},
		   $full) :
		sprintf("%s%10d %5s %3s\t%s\r\n", $flag,
		   $size,
		   $info->{TIME},
		   $info->{BITRATE},
		   $full);
	    $sumTime += $info->{SECS};
	} else {
	    return if $opt_h &&! /\.s?html?$/;
	    return if /\.met$/;
	    return sprintf("%10d %7s = %s\r\n", $size, $full, &extra_part)
		if /\b\d+\.part$/;
	    $output = sprintf("%10d %s\r\n", $size, $full);
	}
	return ($output, $sumTime);
}

sub extra_part {
	my $n = `strings $_.met`;
	# $n = $1 if $n =~ /^(.........................+)$/m;
	$n =~ s/^.{1,8}$//gm;
	$n =~ s/^\s*(\S.+\S)\s*$/\1/gm;
	$n =~ s/\s/ /g;
	return $n;
}

1;
