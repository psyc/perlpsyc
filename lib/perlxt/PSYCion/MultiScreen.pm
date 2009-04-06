package PSYCion::MultiScreen;

use strict;
use Curses;

my ($stdin, $stdout, $stderr, $status);

use PSYCion::Main;
use PSYCion::MultiScreen::Person;
use PSYCion::MultiScreen::Room;
use PSYCion::MultiScreen::Status;

sub new {
    my $conf = { @_ };

    die "No configuration file given!\n" unless ($conf->{'config'});

    *Net::PSYC::W = *W;
    import Net::PSYC qw( :event parse_uniform psyctext );
    require Net::PSYC::Client;
    import Net::PSYC::Client qw(sendmsg UNI enter talk get_context);

    *PSYCion::Main::get_key = *get_key;
    *PSYCion::Main::cmd = *cmd;
    *PSYCion::Main::out = *out;
    *PSYCion::Main::alias = *alias;
    *PSYCion::Main::input = *input;
    $conf->{'uni'} ||= Net::PSYC::Storage::UNI();
    $stdin = $conf->{'stdin'} || *STDIN;
    $stdout = $conf->{'stdout'} || *STDOUT;
    $stderr = $conf->{'stderr'} || *STDERR;
    $status = new PSYCion::MultiScreen::Status($conf->{'uni'}, $conf->{'uni'});
    Net::PSYC::Client::register_context($conf->{'uni'}, $status);

    # inopts
    initscr();
    raw();
    noecho();
    nonl();
    keypad(1);
    nodelay(1);
    idlok(1);

    add($stdin, 'r',
        sub {
	    my ($c, @keys);
	    while (($c = getch()) != ERR) {
		push(@keys, $c);
	    }
            PSYCion::Main::type(@keys);
            return 1;
        });

    PSYCion::Main::load_config($conf->{'config'}) or
	die "Invalid configuration file: $conf->{'config'}\n";


    Net::PSYC::Client::register_new(\&new_window);
    Net::PSYC::Client::psycLink($conf->{'uni'});
    return 1;
}

sub input {
    PSYCion::Window::current()->put(@_);
    PSYCion::Window::current()->draw_prompt();
}

sub resize {
    my ($rows, $cols) = @_;
    Curses::resizeterm($rows, $cols);

    foreach (PSYCion::Window::windows()) {
	$_->resize($rows, $cols);
    }
    my $c = PSYCion::Window::current();
    return unless $c;

    $c->out('_ION_info', 'Resized window to [_lines]:[_columns].',
            {
                '_lines' => $rows,
                '_columns' => $cols,
            });
    
    $c->draw_window();

}

sub get_key {
    my $key = shift;

    if ($key =~ /F(\d+)/i) {
        eval "return Curses::KEY_F$1()" or return;
    }
    return PSYCion::Main::gkey('c-m') if $key =~ /ret/i;
    return Curses::KEY_LEFT() if $key =~ /left/i;
    return Curses::KEY_RIGHT() if $key =~ /right/i;
    return Curses::KEY_DOWN() if $key =~ /down/i;
    return Curses::KEY_UP() if $key =~ /up/i;
    return Curses::KEY_DC() if $key =~ /del/i;
    return Curses::KEY_PPAGE() if $key =~ /pu/i;
    return Curses::KEY_NPAGE() if $key =~ /pd/i;
    return Curses::KEY_HOME() if $key =~ /home|pos1/i;
    return Curses::KEY_END() if $key =~ /end/i;
    #return Curses:: if $key =~ /ins/i;

    return PSYCion::Main::gkey($key);
}

sub draw_prompt {
    PSYCion::Window::current()->draw_prompt();
}

sub out {
    PSYCion::Window::current()->out(@_);
}

sub end {
    noraw();
}

# creates a new window
sub new_window {
    my ($uni, $name, $silent) = @_;
    my $o;

    # temporary solution for silent rooms. they have to be visible somewhere.
    if ($silent) {
	$o = $status;
	return $o if ($o);
    }

    my $t = parse_uniform($uni);
    if ($t->{'object'} =~ /^\~/ ||
	     $t->{'scheme'} eq 'xmpp' || $t->{'scheme'} eq 'mailto') {
	$o = new PSYCion::MultiScreen::Person(@_);
    } elsif ($t->{'object'} =~ /^\@/) {
	$o = new PSYCion::MultiScreen::Room(@_);
    }
    return $o;
}

sub W {
    my $line = shift;
    my $level = shift || 1;

    my $c = PSYCion::Window::windows(0);
    my $mc = ($level == 0) ? '_INTERNAL_error' : '_INTERNAL_debug';
    
    $c->out($mc, $line, {}) if ($c && $level >= Net::PSYC::DEBUG());
}

sub alias {
    my ($alias, $cmd) = @_;
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

1;
