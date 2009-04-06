package PSYCion::MultiScreen::Status;

use strict;

use Net::PSYC::Client qw(sendmsg);
use Net::PSYC qw(psyctext);

use base 'PSYCion::MultiScreen::Gui';

my (%cmd, @buffer);

sub new {
    my $class = shift;
    my $uni = shift;
    my $name = shift;
    my $v =PSYCion::MultiScreen::Gui::new($class, $name);
    $v->{'uni'} = $uni;
    $v->{'name'} = $name;
    $v->{'type'} = 'status';
    $v;
}

sub msg {
    my ($self, $source, $mc, $data, $vars) = @_;
    $self->out($mc, $data, $vars);
    if ($mc =~ /^_notice_unlink/
    ||  $mc eq '_error_invalid_password') {
	print "\r";
	Net::PSYC::stop_loop();
    }
}

sub status {
    my $self = shift;
    sendmsg($self->{'uni'},'_request_description');
}

sub alias { }

sub cmd {
    my $self = shift;
    my $cmd = shift;

    if ($cmd && exists $cmd{$cmd}) {
	my $ret = $cmd{$cmd}->($self, @_);
	return $ret if defined($ret);
    }

    $self->SUPER::cmd($cmd, @_);
}

%cmd = (
'say' => sub {
    my $self = shift;
    my $line = shift;

    my $ret = PSYCion::Main::parse_line($line);
    if ($ret) {
	$self->out('_ION_error', $ret, {});
    } else {
	push(@buffer, $line);
	$self->out('_ION_info', "'$line' returned OK.", {});
    }
    return 1;
},
'save' => sub {
    my $self = shift;
    my $file = shift || $ENV{'HOME'}.'/.psyc/my.ion';
    my ($t, $date);

    unless (@buffer) {
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
	    join("\n", @buffer), "\n") {
	$self->out('_ION_error', "trying to save configuration changes"
		   ." into '$file' failed.\n\t$!", {});
	close(CONFIG);
	return 1;
    }
    close(CONFIG);
    $date = scalar(@buffer);
    $t = "Saved [_amount] command".($date != 1 ? 's' : '')." to [_file].";
    unless ($file eq "$ENV{'HOME'}/.psyc/my.ion") {
	$t .= " You may need to put \n  load [_file]\ninto ~/.psyc/my.ion.";
    }
    $self->out('_ION_info', $t, 
	{
	    '_file' => $file,
	    '_amount' => $date,
	});
    @buffer = ();
    return 1;
},
'drop' => sub {
    my $self = shift;
    
    my $l = scalar(@buffer);
    
    @buffer = () if $l;

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
