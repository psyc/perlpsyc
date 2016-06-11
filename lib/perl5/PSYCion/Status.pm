package PSYCion::Status;

use strict;
use base 'Exporter';

our @EXPORT = '%actions';

our %actions = (
'say' => sub {
    my $self = shift;
    my $line = shift;

    my $ret = PSYCion::Main::parse_line($line);
    if ($ret) {
	$self->out('_ION_error', $ret, {});
    } else {
	push(@{$self->{'buffer'}}, $line);
	$self->out('_ION_info', "'[_line]' returned OK.", 
		  { _line => $line });
    }
    return 1;
},
'save' => sub {
    my $self = shift;
    my $file = shift || $ENV{'HOME'}.'/.psyc/my.ion';
    my ($t, $date);

    unless (@{$self->{'buffer'}}) {
	$self->out('_ION_info', "There are no changes to save.", {});
	return 1;
    }

    $file = $ENV{'HOME'}.'/.psyc/'.$file unless ($file =~ /^\//);

    unless (open(CONFIG, '>>', $file)) {
	$self->out('_ION_error', "trying to save configuration changes"
		   ." into '[_file]' failed.\n\t[_error]", 
		   {
		       '_file' => $file,
		       '_error' => $!,
		   });
	return 1;
    }
    # do we need nonblocking writes here??
    # we could do that. maybe TODO
    $date = localtime(); 
    
    unless (print CONFIG "# saved by psycion v$main::VERSION on $date\n", 
	    join("\n", @{$self->{'buffer'}}), "\n") {
	$self->out('_ION_error', "trying to save configuration changes"
		   ." into '$file' failed.\n\t$!", {});
	close(CONFIG);
	return 1;
    }
    close(CONFIG);
    $date = scalar(@{$self->{'buffer'}});
    $t = "Saved [_amount] command".($date != 1 ? 's' : '')." to [_file].";
    unless ($file eq "$ENV{'HOME'}/.psyc/my.ion") {
	$t .= " You may need to put \n  load [_file]\ninto ~/.psyc/my.ion.";
    }
    $self->out('_ION_info', $t, 
	{
	    '_file' => $file,
	    '_amount' => $date,
	});
    $self->{'buffer'} = [];
    return 1;
},
'drop' => sub {
    my $self = shift;
    
    my $l = scalar(@{$self->{'buffer'}});
    
    $self->{'buffer'} = [] if $l;

    $self->out('_ION_info', 
		"Dropped [_amount] command".($l == 1 ? '.' : 's.'),
		{ '_amount' => $l });
},
'remove' => sub {
    my $self = shift;
    $self->out('_ION_error', 'No Way!', {});
    return 1;
},
);

1;
