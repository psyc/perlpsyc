#!/usr/bin/perl -I/usr/depot/lib/perl5
#

use vars qw($plugin $T $query);
use strict;

use MT;
use MT::Plugin;
use MT::PluginData;
use Net::PSYC;

sub NAME { "PSYC Plugin, v.0.1" }

#############################################################################
# psyc.pl  -  PSYC notification plugin
# 
# PSYC is an innovative protocol for chat servers and conferencing
# in general. see http://www.psyc.eu for further information about
# the protocol.
# 
# This plugin enables your Weblog to send notifications to persons or 
# chatrooms in the PSYC-space. It may also be used to tell a newsroom
# on a psyced to poll the updated RSS file.
# See also http://about.psyc.eu/Create_Place
#      and http://about.psyc.eu/Newscasting
#
# In case you dont know about PSYC and do not have a PSYC-address.. either
# get yourself a free psyced from http://www.psyced.org and host your
# own chat community (in addition to native PSYC the server supports IRC, 
# Jabber and offers a telnet interface) or just point
# 	your browser at http://psyced.org
# 	your IRC client at psyced.org:6667
# 	your favourite telnet-client at psyced.org
# 	your Jabber client at psyced.org:5222
# and register a nickname. Your new PSYC-adress would be
# psyc://psyced.org/~nick. 
#
# 
# 
# 
# Arne Gödeke
# el@goodadvice.pages.de
# psyc://psyced.org/~el
# 
#############################################################################




my $data = MT::PluginData->load({ plugin => NAME(),
				  key    => 'notify_list' });
$T = $data->data;

$plugin = new MT::Plugin();

$plugin->name(NAME());
$plugin->description("Enables your blog to send notifications via PSYC.");
$plugin->config_link("../psycconf.pl");
#$plugin->doc_link("http://www.elridion.de/MT-psyc/");
    
MT->add_plugin($plugin);


MT::Entry->add_callback("post_save", 1, $plugin, \&entry_add);
MT::Entry->add_callback("pre_remove", 1, $plugin, \&entry_remove);

# RSS
MT::Entry->add_callback("post_save", 2, $plugin, \&rss_change);
MT::Entry->add_callback("post_remove", 2, $plugin, \&rss_change);

MT::Comment->add_callback("post_save", 1, $plugin, \&comment_add);
MT::Comment->add_callback("pre_remove", 1, $plugin, \&comment_remove);
MT::Comment->add_callback("pre_remove_all", 1, $plugin, \&comment_remove_all);

# remove the notify list
MT::Blog->add_callback("pre_remove", 1, $plugin, \&blog_remove);

sub entry_add {
    my $plugin = shift;
    my $entry = shift;
    
    return if($entry->status eq '1'); # draft!
    
    print STDERR "ENTRY_ADD";
    my $author = MT::Author->load($entry->author_id);
    my $blog = MT::Blog->load($entry->blog_id);

    my $target = $T->{$entry->blog_id};
    
    if (($entry->modified_on - $entry->created_on) > 3600 && ref $target->{'entry_edit'}) {
	
	foreach ( @{$target->{'entry_edit'}} ) {
	    sendmsg($_, '_notice_blog_entry_edited', 
		    '([_blog]) "[_entry_title]" has been edited by [_entry_author]. ([_url])', 
		    {
			_nick=>$blog->name,
			_blog=>$blog->name,
			_entry_author=>$author->name,
			_entry_title=>$entry->title,
			_url=>$entry->permalink,
		    });
	}
    } elsif (ref $target->{'entry_add'}) {
	
	foreach ( @{$target->{'entry_add'}} ) {
            sendmsg($_, '_notice_blog_entry_added',  
                    '([_blog]) "[_entry_title]" published by [_entry_author]. ([_url])',
                    {
			_nick=>$blog->name,
			_blog=>$blog->name,
                        _entry_author=>$author->name,
                        _entry_title=>$entry->title,
			_url=>$entry->permalink,
                    });	
	}
    }
}

sub entry_remove {
    my $plugin = shift;
    my $entry = shift;
    
    return if($entry->status eq '1'); # draft!
    
    print STDERR "ENTRY_REMOVE";
    my $author = MT::Author->load($entry->author_id);
    my $blog = MT::Blog->load($entry->blog_id);

    my $target = $T->{$entry->blog_id};
    return unless (ref $target->{'entry_remove'});
    
    foreach ( @{$target->{'entry_remove'}} ) {
	sendmsg($_, '_notice_blog_entry_removed',
		'([_blog]) "[_entry_title]" has been removed.',
		{   
		    _nick=>$blog->name,
		    _blog=>$blog->name,
		    _entry_author=>$author->name,
		    _entry_title=>$entry->title,
		    _url=>$entry->permalink,
                });	
    }
}

sub rss_change {
    my $plugin = shift;
    my $entry = shift; 

    return if($entry->status eq '1'); # draft!
    print STDERR "RSS_CHANGE";

    my $blog = MT::Blog->load($entry->blog_id);
    my $target = $T->{$entry->blog_id};

    return unless (ref $target->{'rss_change'});

    foreach ( @{$target->{'rss_change'}} ) {
        sendmsg($_, '_notice_update_blog',
                '([_nick]) [_location_feed] changed.',
                {
                    _nick=>$blog->name,
                    _location_feed=>$blog->site_url,
                });
    }
    
}

sub comment_add {
    my $plugin = shift;
    my $comment = shift;
    
    print STDERR "COMMENT_ADD";
    my $target = $T->{$comment->blog_id};
    my $blog = MT::Blog->load($comment->blog_id);
    my $entry = MT::Entry->load($comment->entry_id);
    my $entry_author = $entry->author;

    if (($comment->modified_on - $comment->created_on) > 3600 && ref $target->{'comment_edit'}) {
        
        foreach ( @{$target->{'comment_edit'}} ) {
            sendmsg($_, '_notice_blog_comment_edited',
                    '([_blog]) [_comment_author]\'s comment on "[_entry_title]" has been edited.',
                    {
                        _nick=>$blog->name,
                        _blog=>$blog->name,
                        _comment_author=>$comment->author,
                        _entry_author=>$entry_author->name,
			_entry_title=>$comment->title,
                    });
        }
    } elsif (ref $target->{'comment_add'}) {

        foreach ( @{$target->{'entry_add'}} ) {
            sendmsg($_, '_notice_blog_comment_added',
                    '([_blog]) [_comment_author] posted a comment on "[_entry_title]".',
                    {   
                        _nick=>$blog->name,
			_blog=>$blog->name,
			_comment_author=>$comment->author,
                        _entry_author=>$entry_author->name,
			_entry_title=>$comment->title,
                    });
        }
    }

}
# visible, ip, author, entry_id, email, modified_on, created_on, text, url, id, blog_id

sub comment_remove {
    my $plugin = shift;
    my $comment = shift;
 
    my $target = $T->{$comment->blog_id};
    return unless (ref $target->{'comment_remove'});
    
    my $blog = MT::Blog->load($comment->blog_id);
    my $entry = MT::Entry->load($comment->entry_id);
    my $entry_author = $entry->author;
    
    foreach (@{$target->{'comment_remove'}}) {
	sendmsg($_, '_notice_blog_comment_removed',
		'([_blog]) Comment by [_comment_author] on "[_entry_title]" removed.',
		{
		    _nick=>$blog->name,
		    _blog=>$blog->name,
		    _comment_author=>$comment->author,
		    _entry_author=>$entry_author->name,
		    _entry_title=>$entry->title,
		});
    }
}
# visible, ip, author, entry_id, email, modified_on, created_on, text, url, id, blog_id
#
sub comment_remove_all {
    my $plugin = shift;
    my $comment = shift;

    my $target = $T->{$comment->blog_id};
    return unless (ref $target->{'comment_remove_all'});
    
    my $blog = MT::Blog->load($comment->blog_id);
    my $entry = MT::Entry->load($comment->entry_id);
    my $entry_author = $entry->author;

    foreach (@{$target->{'comment_remove'}}) {
        sendmsg($_, '_notice_blog_comment_removed',
                '([_blog]) All comments on "[_entry_title]" removed.',
                {
                    _nick=>$blog->name,
                    _blog=>$blog->name,
                    _comment_author=>$comment->author,
                    _entry_author=>$entry_author->name,
                    _entry_title=>$entry->title,
                });
    }    
}

# remove the notify list if a blog is removed!
sub blog_remove {
    my $plugin = shift;
    my $blog = shift;
    if (exists $T->{$blog->id}) {
	delete $T->{$blog->id};
	$data->data($T);
	$data->save;
    }
}


1;
