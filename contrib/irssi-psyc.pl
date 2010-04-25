# This is a very old prototype for irssi-psyc.
# To obtain the current full fledged version,
# please consult http://about.psyc.eu/irssi


# should this become Net::PSYC::Irssi.pm ?

use strict;
use Irssi qw(active_win);

use vars qw($psyc $VERSION %IRSSI $pp $user $nick $window);
use Data::Dumper;
# TODO: please upgrade to Net::PSYC; merge anything in you need
use Net::ooPSYC;

$VERSION = '0.2';
%IRSSI = (
    authors     => 'Dominik Sander',
    contact     => 'dominik@goodadvice.pages.de',
    name        => 'IrssiPSYC',
    description => 'Implements the PSYC protocol (www.psyc.eu) for irssi.',
    license => 'Public Domain',
    url     => 'http://www.depairet.de/',
    changed => 'Tue Sep  2 16:05:17 CEST 2003',
);

sub sig_send_text {
    my ($text, $foo1, $foo2) = @_;	
    my $win = Irssi::active_win;
    print ">>>user input: $text";
    my ($u, $h, $p, $t, $o) = $psyc->parse_uniform($window->{$win->{'name'}}) or return;
    my $mc = ($win->{'name'} =~ /^~/) ? '_message_private' : '_message_public';
    $psyc->sendmsg($window->{$win->{'name'}},$mc,$text,{_nick=>$user->{'nick'}}) if $window->{$win->{'name'}} =~ /^psyc/;
}

sub cmd_psyc {
    my ($args, $server, $witem) = @_;
    my @arg = split / +/, $args;
    my $switch = {
	'disc'		=> sub { pre_unload(); },
	'win' 		=> sub { cb_place_enter(); },
	'dumprooms'	=> sub {
	    print map { "$_ => $window->{$_}\%n\n" } keys %$window 
	}
    };
    if(exists $switch->{$arg[0]}) { &{$switch->{$arg[0]}}; }
    else { print "huh?"; }
}

# verbindung zum server aufnehemn
sub cmd_connect {
    my ($uni, $witem) = @_;
    my $nick;
    $user->{'uni'} = (Irssi::settings_get_str('uni') || $uni);
    $user->{'nick'} = Irssi::settings_get_str('nick');
    if($user->{'uni'} !~ /^psyc/ && !$user->{'uni'}) { return; }
    ($user->{'server_uni'} = $user->{'uni'}) =~ s/\w+\@|~.*$//g;
    print ">>>connect ARGS: $user->{'uni'},";
    $psyc->sendmsg($user->{'uni'},'_request_link','Pleeease',{_nick=>$user->{'nick'} });
    Irssi::signal_stop();
}

sub cmd_join {
    my ($uni, $witem) = @_;
    my $target = ($uni =~ /^psyc/) ? $uni : ($user->{'server_uni'}.'@'.$uni);
    $psyc->sendmsg($target,'_request_enter','',{_nick=>$user->{'nick'} });
}

sub cmd_part {
    my ($args, $witem) = @_;
    if(!$args) {
	my $win = Irssi::active_win;
	$psyc->sendmsg($window->{$win->{'name'}},'_request_leave','Bye bye',{_nick=>$user->{'nick'}} );
    } elsif($args eq 'ALL') {
	
    }
}

sub cmd_query {
    my ($args, $witem) = @_;
    my ($newwin, $ru, $rh, $rp, $rt, $ro);
    my @arg = split(/\s+/,$args);
    my ($u, $h, $p, $t, $o) = $psyc->parse_uniform($user->{'uni'});	
    foreach(@arg) {
	$_ =~ s/^~//;
	print $_;
	if($_ =~ /^psyc\:\/\//) {
	    ($ru, $rh, $rp, $rt, $ro) = $psyc->parse_uniform($_);
	}
	print "cmd_query l: $u, $h, $p, $t, $o";
	print "cmd_query r: $u, $h, $p, $t, $o";
	$window->{'~'.($ru || $_)} = $rh ? 'psyc://'.$rh.':'.$rp.'/~'.$ru : 'psyc://'.$h.':'.$p.'/~'.$_;
	createWindow('~'.($ru || $_));
    }
    return $newwin;
}

sub cb_connected {
    my ($my, $data, $vars) = @_;
    print $pp."connected to $vars->{'_source'}";
    print $pp."online friends: $vars->{'_friends'}";
}

sub cb_place_enter {
    my ($my, $data, $vars) = @_;
    my ($u, $h, $p, $t, $o) = Net::ooPSYC::parse_uniform($vars->{'_context'} || $vars->{'_source'}) or return;
    if($window->{$o}) {
	my $win = Irssi::window_find_name($o);
	$win->printformat(MSGLEVEL_MSGS, 'irssiPSYC_join',$vars->{'_nick'});
	return;
    }
    print "parse_uniform: $u, $h, $p, $t, $o";
    $window->{$o} = ($vars->{'_context'} || $vars->{'_source'}); 
    my $newwin = Irssi::Windowitem::window_create(lc $o, 1);	
#    print Dumper($newwin);
    $newwin->set_name($o);
    $newwin->set_active();

}

sub cb_place_leave {
    my ($my, $data, $vars) = @_;
    my ($u, $h, $p, $t, $o) = Net::ooPSYC::parse_uniform($vars->{'_context'} || $vars->{'_source'}) or return;
    if($window->{$o}) {
	my $win = Irssi::window_find_name($o);
	if($vars->{'_source'} eq $user->{'uni'}) {
	    delete $window->{$o};
	    $win->destroy();
	} else {
	    $win->printformat(MSGLEVEL_MSGS, 'irssiPSYC_leave',$vars->{'_nick'});
	}
    }
}

sub cb_message {
    my ($mc, $data, $vars) = @_;
    my $isme;
    my ($u, $h, $p, $t, $o) = Net::ooPSYC::parse_uniform($vars->{'_context'} || $vars->{'_source'}) or return;
    my $active = lc $o || $vars->{'_nick_place'} || '~'.$u;
    if($active !~ /^[~@]/) { $active = '@'.$active; } # ein bisschen sehr hackig ... geht das besser?
    my $win = Irssi::window_find_name($active);
    unless($win) { # que
	$window->{$active} = ($vars->{'_context'} || $vars->{'_source'});    
	$win = createWindow($active,'nofocus'); 
    }
    my $action = ($mc eq '_message_public_question') ? ' frag'.$isme.'t' : ' '.($vars->{'_action'} || 'sag'.$isme.'t');	
    $win->printformat(MSGLEVEL_MSGS, 'irssiPSYC_public',$vars->{'_nick'},$action,$data) if $win;
}

sub cb_query_password {
    my ($mc, $data, $vars) = @_;
    Irssi::settings_get_str('password') ? setPassword(Irssi::settings_get_str('password')) : promtPassword();
}

sub promtPassword {
    print "Please provide your password with /PASSWORD <PASSWORD>";
}

sub setPassword {
    $psyc->sendmsg($user->{'uni'},'_set_password','',{_password=>$_[0]});
}

sub createWindow {
    my $newwin = Irssi::Windowitem::window_create($_[0], 1);
    $newwin->set_name($_[0]);
    $newwin->set_active() if $_[0] ne 'nofucus';
    return $newwin;
}

sub compareUNL {
    my @unls = @_;
    my ($prev,$cur);
    foreach(@unls) {
	print $_;
	print "cur: $cur\npre: $prev\n";
#	$cur = join('',@{$psyc->parse_uniform($_)});
	$cur = $psyc->parse_uniform($_);
	print $cur;
	unless($prev) { $prev = $cur; next; }
	return 0 unless ($prev eq $cur);
	$prev = $cur;
    }
    return 1;
}

# Wegen zwei vorhandenen Event-loop's muss leider der Socket gepolled werden
# ooPSYC hat deshalb ein Select interface bekommen
sub checkSocket {
    $psyc->dirty_getmsg();
}

# irssi zerstört die genutzen objekte nicht richtig, also ist ahdnarbeit gefragt
sub pre_unload {
    print "irssi-psyc unloaded. irrsi functions are back normal";
    $psyc->sendmsg($user->{'uni'},'_request_unlink',"Bye Bye");
    print $psyc->DESTROY;
}

Irssi::theme_register(
		    [ # have a look at http://www.irssi.org/?page=docs&doc=special_vars
			'irssiPSYC_public', 
			'$0$1: $2', # $0 = nick, $1 = action, $2 = text
			'irssiPSYC_join',
			'$0 enters',
			'irssiPSYC_leave',
			'$0 leaves',
		    ]);

Irssi::settings_add_str($IRSSI{name}, 'nick', 'test');
Irssi::settings_add_str($IRSSI{name}, 'password', 'haha');
Irssi::settings_add_str($IRSSI{name}, 'uni', 'psyc://dominik.sander.net/~test');

Irssi::signal_add('send text', \&sig_send_text);
Irssi::signal_add('module unloaded', \&unload);

Irssi::command_bind('connect','cmd_connect');
Irssi::command_bind('psyc','cmd_psyc');
Irssi::command_bind('join','cmd_join');
Irssi::command_bind('password','setPassword');
Irssi::command_bind('part','cmd_part');
Irssi::command_bind('query','cmd_query');

$psyc = Net::ooPSYC->new('psyc://dominik:4442/');
print $psyc->setSource('psyc://dominik.sander.net:4442/~test');
$psyc->addHandler('_notice_link', \&cb_connected);
$psyc->addHandler('_notice_place_enter', \&cb_place_enter);
$psyc->addHandler('_status_person_present_netburp',\&cb_place_enter);
$psyc->addHandler('_message', \&cb_message);
$psyc->addHandler('_query_password', \&cb_query_password);
$psyc->addHandler('_notice_place_leave', \&cb_place_leave);

Irssi::timeout_add(100,'checkSocket','');

