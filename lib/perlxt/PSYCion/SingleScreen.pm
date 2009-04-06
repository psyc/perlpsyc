package PSYCion::SingleScreen;

use strict;
# this is a single-screen gui.. 
#
my ($term, $stdin, $stdout, $status, $stderr);
use Term::Cap;
use Term::ANSIColor;

use Net::PSYC qw(:event parse_uniform psyctext setDEBUG DEBUG);
use Net::PSYC::Client qw(sendmsg UNI enter talk);
use PSYCion::Main;
use PSYCion::SingleScreen::Status;
use PSYCion::SingleScreen::Room;
use PSYCion::SingleScreen::Person;

# creates a new window.. this is virtual in this case
# $conf = {
#	uni => 'uni',
#	password => string|callback,
#	stdin => fd,
#	stdout => fd,
#	stderr => fd,
#	config => filename,
# };

# isa PSYCion::Main;
sub new {
    my $conf = { @_ };

    die "No configuration file given!\n" unless ($conf->{'config'});

    *PSYCion::Main::get_key = *get_key; 
    *PSYCion::Main::cmd = *cmd; 
    *PSYCion::Main::out = *out;
    *PSYCion::Main::alias = *alias;
    *PSYCion::Main::input = *input;
    $conf->{'uni'} ||= Net::PSYC::Storage::UNI();
    $stdin = $conf->{'stdin'} || *STDIN;
    $stdout = $conf->{'stdout'} || *STDOUT;
    $stderr = $conf->{'stderr'} || *STDERR;
    $status = new PSYCion::SingleScreen::Status($conf->{'uni'}, $conf->{'uni'});
    Net::PSYC::Client::register_context($conf->{'uni'}, $status);

    select($stdin); $| = 1; # unbuffered STDIN
    select($stdout); $| = 1;
    system "stty raw -echo"; # this one is a problem if self->stdin != STDIN
    add($stdin, 'r', 
	sub { 
	    my $stdin = shift; 
	    my $data;
	    sysread($stdin, $data, 256);
	    PSYCion::Main::type(split(//, $data)); 
	    return 1;
	});

    $term = Tgetent Term::Cap { OSPEED => 9600, TERM => $conf->{'TERM'} };
    # ^^ will croak on failure.
    $term->Trequire(qw/dl cl do kb kl kr kd ku kD kP kN kh kI bc k1 k2 k3 k4 k5 k6 k7 k8 k9 RI/);

    PSYCion::Main::load_config($conf->{'config'}) or 
	die "Invalid configuration file: $conf->{'config'}\n";

    #
    # Net::PSYC::Client has to be rewritten to the object way.. importante!
    # maybe not that important.. this new structure is good for clarity anyhow
    Net::PSYC::Client::register_new(\&new_window);
    Net::PSYC::Client::psycLink($conf->{'uni'});
    return 1;
}

my %key2cap = (
    'left' => 'kl',
    'right' => 'kr',
    'up' => 'ku',
    'down' => 'kd',
    'del' => 'kD',
    'pu' => 'kP',
    'pd' => 'kN',
    'home' => 'kh',
    'ins' => 'kI',
);
$key2cap{'pos1'} = $key2cap{'home'};

sub get_key {
    my $key = shift;
    
    if ($key =~ /F(\d)/i) {
	return split(//, $term->Tputs('k'.$1));
    }
    return PSYCion::Main::gkey('c-m') if $key =~ /ret/i;

    if (exists $key2cap{lc($key)}) {
	return split(//, $term->Tputs($key2cap{lc($key)}));
    }
    
    return PSYCion::Main::gkey($key);
}

sub new_window {
    my $uni = shift;
    my $name = shift;
    my $u = parse_uniform($uni);
    my $silent = shift;
    my $o;

    return $status if ($silent || !$u->{'object'});

    if ($u->{'scheme'} eq 'xmpp' || $u->{'scheme'} eq 'mailto' ||
	$u->{'object'} =~ /^\~/) {
	$o = new PSYCion::SingleScreen::Person($uni, $name);
    }

    if ($u->{'object'} =~ /^@/) {
	$o = new PSYCion::SingleScreen::Room($uni, $name);
    }
    
    if ($o) {
	return $o;
    }

    return $status;
}

sub end {
    system "stty -raw echo";
}

sub del_screen {
    return $term->Tputs('cl', 1) if defined(wantarray);
    $term->Tputs('cl', 1, $stdout);
}

sub del_line {
    return $term->Tputs('cr', 1).$term->Tputs('dl', 1) if defined(wantarray);
    $term->Tputs('cr', 1, $stdout);
    $term->Tputs('dl', 1, $stdout);
}

sub new_line {
    return $term->Tputs('cr', 1).$term->Tputs('do', 1) if defined(wantarray);
    $term->Tputs('cr', 1, $stdout);
    $term->Tputs('do', 1, $stdout);
}

sub draw_prompt {
    my $c = PSYCion::Window::current();
    del_line();
    $term->Tpad($c->prompt(), 1, $stdout);
    $term->Tputs('cr', 1, $stdout);
    $term->Tgoto('RI', 0, $c->curs_pos(), $stdout);
}

sub output {
    my @data = @{$_[0]};
    my $str;
    foreach (@data) {
        if (ref $_ eq 'ARRAY') {
            if ($_->[0]) {
                $str .= color('on_'.join(' ', @$_));
            } else {
                $str .= color(join(' ', @$_));
            }
        } else {
            $str .= $_.Term::ANSIColor::RESET();
        }
    }
    
    @data = split(/[\n\r]+/, $str);
    del_line();
    foreach $str (@data) {
        $term->Tpad($str, 0, $stdout);
        new_line();
    }
    draw_prompt();
}

sub out {
    output(PSYCion::Main::render(@_));
}

sub input {
    PSYCion::Window::current()->put(@_);
    draw_prompt();
}

sub resize {
    my ($rows, $cols) = @_;
    foreach (PSYCion::Window::windows()) {
	$_->resize($rows, $cols);
    }
    draw_prompt();
}

sub alias {
    return 1;
    my ($alias, $cmd) = @_;
    if (exists $actions{$cmd}) {
	$actions{$alias} = $actions{$cmd};
	return 1;
    }
    &PSYCion::SingleScreen::Window::alias
    +  &PSYCion::SingleScreen::Status::alias
    +  &PSYCion::SingleScreen::Room::alias
    +  &PSYCion::SingleScreen::Person::alias; 
}

sub cmd {
    my $cmd = shift;
    my $c = PSYCion::Window::current();

    return 1 if ($c->cmd($cmd, @_));
    if (exists $actions{$cmd} && $actions{$cmd}->($c, @_)) {
	return 1;
    }
    return 0;
}

$actions{'execute'} = sub {
    my $self = shift;
    my $data = shift;
    my $c = PSYCion::SingleScreen::Room::current();
    # new! you can now also pass the UNI of your current query
    # not just your current place.
    my $v = $c ? { '_focus' => $c->{'uni'} } : {}; 
    sendmsg(UNI(), '_request_execute', $data, $v);
};

1;
