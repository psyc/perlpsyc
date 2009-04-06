#!/usr/bin/perl -w

use strict;

my($MT_DIR);
BEGIN {
    if ($0 =~ m!(.*[/\\])!) {
        $MT_DIR = $1;
    } else {
        $MT_DIR = './';
    }
    $MT_DIR =~ s/plugins\///g;
    unshift @INC, $MT_DIR . 'lib';
    unshift @INC, $MT_DIR . 'extlib';
}

eval {
    @MT::App::PSYCConf::ISA = qw( MT::App );
    my $app = MT::App::PSYCConf->new( Config => $MT_DIR . 'mt.cfg',
                                      Directory => $MT_DIR )
        or die MT->errstr;
    local $SIG{__WARN__} = sub { $app->trace($_[0]) };
    
    my ($author, $first_time) = $app->login;
    
    if (ref $author eq 'MT::Author') {
	$app->run();
    } else {
	print "Content-Type: text/html\n\n";
	print "Log into <a href='mt.cgi'>MovableType</a> first!\n";
    }
};

if ($@) {
    print "Content-Type: text/html\n\n";
    print "Got an error: $@";
}

package MT::App::PSYCConf;

use MT::App;

sub NAME { "PSYC Plugin, v.0.1" }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods('config' => \&view_config,
                      'add' => \&add,
                      'del' => \&del,
		      'reset'=> \&reset);
    
    $app->{default_mode} = 'config';
    $app->{charset} = $app->{cfg}->PublishCharset;
    $app->{requires_login} = 1;
    MT::Object->set_driver($app->{cfg}->ObjectDriver);
    $app->{user_class} = 'MT::Author';
}


sub view_config {
    my $app = shift;
    my $data = MT::PluginData->load({ plugin => NAME(),
	                           key    => 'notify_list' });
    my $T = $data->data;
    my $title = NAME();
    my $html = <<EOF;
<head>
<title>$title</title>
<link rel="stylesheet" href="/MT/styles.css" type="text/css" />
</head>
<br>
<a href="mt.cgi">Movable Type</a><br><br>
<table border=1 width='80%' style="margin-left: 30px">
<tr><th width='10%'>Blog</th><th>Event</th><th>UNIs</th></tr>
EOF
    foreach my $blog (keys %$T) {
	my $b = MT::Blog->load($blog);
	my $blog_name = $b->name;
	my $blog_url = $b->site_url;
        my $rowspan = scalar(keys %{$T->{$blog}});
        next unless ($rowspan);
        $html .= "<tr><td rowspan=$rowspan valign=top><a href='$blog_url'>$blog_name</a><br>Id: $blog</td>";
        foreach my $event (keys %{$T->{$blog}}) {
            next unless (@{$T->{$blog}->{$event}});
            $html .= "<td valign=top>$event</td><td>";
            $html .= join("<br>", map("$_ <a href=\"psycconf.pl?__mode=del&blog_id=$blog&event=$event&uni=$_\">delete</a>", @{$T->{$blog}->{$event}}));
            $html .= "</td></tr>";
        }
    }
    $html .= <<EOF;
</table>
<center><form action='psycconf.pl' method=GET><input type=hidden name='__mode' value=add>Blog ID: <input name='blog_id' size=3> Event: <select name=event size=1>
<option>entry_add</option>
<option>entry_edit</option>
<option>entry_remove</option>
<option>comment_add</option>
<option>comment_edit</option>
<option>comment_remove</option>
<option>rss_change</option>
</select>
UNI: <input name=uni size=30 value='psyc://host:port/~nick'> <input type=submit value=add><br>
<br>
<br>
<p style="text-align: justify; margin: 30px;">
Simply add the PSYC-address you want to be notified if an event occurs.<br> You have no idea how a PSYC-Adress looks like? Its rather simple: <b>psyc://<i>server</i>:<i>port</i>/~<i>nick</i></b> for a users identification at his home-server or <b>psyc://<i>server</i>:<i>port</i>/@<i>room</i></b> for a chatroom.
<br><br>
visit <a href="http://www.psyc.eu">www.psyc.eu</a> for more information about the idea behind PSYC and the protocol itself AND <a href="http://www.psyced.org">www.psyced.org</a> to get yourself a psyced (an open-source PSYC-Server which also supports other protocols like IRC, Jabber and even a telnet interface).
<br>
</p>
</body>
EOF
    $html;
}

sub add {
    my $app = shift;
    my $query = $app->{query};
    my $data = MT::PluginData->load({ plugin => NAME(),
                                      key    => 'notify_list' });
    my $T = $data->data;

    my $blog_id = $app->{query}->param('blog_id');
    my $event = $app->{query}->param('event');
    my $uni = $app->{query}->param('uni');
    
    return view_config() unless ($uni && $event && $blog_id);
    return view_config() if (ref $T->{$blog_id}->{$event} && grep { $_ eq $uni } @{$T->{$blog_id}->{$event}});
    return view_config() unless (MT::Blog->load($blog_id));
	    
    $T->{$blog_id}->{$event} = [] unless ($T->{$blog_id}->{$event});
    push(@{$T->{$blog_id}->{$event}}, $uni);
    
    $data->data($T);
    $data->save or die $data->errstr;
    
    return view_config();
}

sub del {
    my $app = shift;
    my $query = $app->{query};
    my $data = MT::PluginData->load({ plugin => NAME(),
                                   key    => 'notify_list' });
    my $T = $data->data;
    
    my $blog_id = $app->{query}->param('blog_id');
    my $event = $app->{query}->param('event');
    my $uni = $app->{query}->param('uni');

    return view_config() unless ($blog_id && $event && $uni);
    return view_config() unless (ref $T->{$blog_id}->{$event});   
        # remove the adress
    $T->{$blog_id}->{$event} = [ grep { $_ ne $uni } @{$T->{$blog_id}->{$event}} ];
    
    delete $T->{$blog_id}->{$event} unless (@{$T->{$blog_id}->{$event}}); 
    delete $T->{$blog_id} unless (keys %{$T->{$blog_id}});
    
    $data->data($T);
    $data->save or die $data->errstr;
    
    return view_config();
}

sub reset {
    my $app = shift;
    my $data = MT::PluginData->load({ plugin => NAME(),
				       key    => 'notify_list' });
    my $T = $data->data;
    $data->data({});
    $data->save or die $data->errstr;
    return view_config();
}


1;
