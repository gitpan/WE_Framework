# -*- perl -*-

#
# $Id: Notify.pm,v 1.15 2005/01/10 08:29:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::Notify;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

use Mail::Send;
use Mail::Mailer 1.53;
use Data::Dumper;
use WE::Util::LangString qw(langstring);
use Sys::Hostname qw(hostname);

# 0: no debugging
# 1: show notify calls
# 2: trace SMTP, show args to Mail::Send
use constant DEBUG => 0;

sub notify {
    my($self, $action, $info, $retinfo) = @_;
    warn "Notify $action $info...\n" if DEBUG;

    my $c = $self->C;
    my $f = $c->project->features;
    my $rcvs = $f && $f->{notify} && $f->{notify}{$action};
    if (!$rcvs) {
	$rcvs = [];
    } else {
	if (!UNIVERSAL::isa($rcvs, "ARRAY")) {
	    $rcvs = [split /\s*,\s*/, $rcvs];
	}
    }
    my $all = $f->{notify}{all};
    if ($all) {
	if (UNIVERSAL::isa($all, "ARRAY")) {
	    push @$rcvs, @$all;
	} else {
	    $all = [split /\s*,\s*/, $all];
	    push @$rcvs, @$all;
	}
    }
    warn "Found notify receivers: @$rcvs\n" if DEBUG;

    if (@$rcvs) {
	if ($c->siteext && $c->siteext->notify_background) {
	    if (fork == 0) {
		$self->do_notify($action,
				 -info      => $info,
				 -receivers => $rcvs,
				);
		CORE::exit(0);
	    }
	    if ($retinfo) {
		# XXX langres
		$retinfo->{message} = "Notify process started.";
	    }
	} else {
	    eval {
		my $_retinfo =
		    $self->do_notify($action,
				     -info      => $info,
				     -receivers => $rcvs,
				    );
		if ($retinfo) {
		    $retinfo->{receivers} = $_retinfo->{receivers}
		}
	    };
	    if ($@) {
		if ($retinfo) {
		    $retinfo->{message} = $@;
		}
		warn $@;
	    }
	}
    }
}

sub do_notify {
    my $self = shift;
    my $action = shift;
    my %args = @_;
    my $retinfo = {};
    my $info      = delete $args{-info};
    my $receivers = delete $args{-receivers};
    die "Unknown arguments: " . join(", ", %args) if %args;
    if (!$receivers) {
	die "No receivers";
    }
    $receivers = $self->resolve_notify_receivers($receivers);
    if (!@$receivers) {
	warn "Resolved to null receivers";
	$retinfo->{receivers} = [];
	return $retinfo;
    }

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;
    my $user  = $root->CurrentUser || "unknown";

    my $subject = "web.editor system message: $action (site @{[ $c->project->longname ]})";

    my @mailerargs;
    if ($c->siteext && $c->siteext->notify_mailer) {
	@mailerargs = @{ $c->siteext->notify_mailer };
    }
    if (@mailerargs && $mailerargs[0] eq 'smtp' && DEBUG >= 2) {
	push @mailerargs, Debug => 10;
    }

    my $msg = new Mail::Send Subject => $subject;
    for my $receiver (@$receivers) {
	$msg->add("To", $receiver);
    }
    $msg->add("MIME-Version", "1.0");
    $msg->add("Content-Type", "text/html; charset=ISO-8859-1");
   # $msg->add("Content-Transfer-Enconding", "8bit");
# XXX Verwendung von Templates?
# XXX de vs. en?
# XXX Besserer Text
    my $fh = $msg->open(@mailerargs);
    if (DEBUG >= 2) {
	require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@mailerargs],[])->Indent(1)->Useqq(1)->Dump;
    }

    print $fh <<EOF;
<x-html>
The action <b>`$action'</b> was performed by <b>`$user'</b> <br>
in the web.editor system for the site <b> @{[ $c->project->longname ]} </b> <br>
on host @{[ hostname() ]}.
EOF
    if ($info) {
	while(my($k,$v) = each %$info) {
	    if ($k eq 'Id') {
		my @ids = UNIVERSAL::isa($v, "ARRAY") ? @$v : $v;
		my @titles = map {
		    my $o = $objdb->get_object($_);
		    if ($o) {
			langstring($o->Title);
		    } else {
			"Object with Id $_";
		    }
		} @ids;
		if (@titles > 10) {
		    splice @titles, 10;
		}
		print $fh "\n<br>";
		print $fh "Documents (@ids): ";
		print $fh join(", ", map { WebEditor::OldController::_html($_) } @titles) . "\n<br>";
		delete $info->{$k};
	    }
	}
	if (keys %$info) {
	    print $fh "<br>\nAdditional information:\n<br>";
	    print $fh Dumper($info);
	}
    }
    print $fh "</x-html>";
    $fh->close;

    $retinfo->{receivers} = $receivers;

    $retinfo;
}

sub resolve_notify_receivers {
    my($self, $receivers) = @_;
    my $userdb = $self->Root->UserDB;
    my @new_receivers;

    my $add_user = sub {
	my $username = shift;
	my $user = $userdb->get_user($username);
	if ($user) {
	    if ($user->{email}) {
		push @new_receivers, $user->{email};
	    } else {
		warn "The notify user <" . $username . "> has no email address!";
	    }
	} else {
	    warn "The username $username is unknown";
	}
    };

    for my $receiver (@$receivers) {
    TRY: {
	    if ($receiver =~ /\@/) {
		push @new_receivers, $receiver;
		last TRY;
	    }

	    if ($userdb->user_exists($receiver)) {
		$add_user->($receiver);
		last TRY;
	    }

	    my @users = $userdb->get_users_of_group($receiver);
	    if (@users) {
		$add_user->($_) for (@users);
	    } else {
		warn "The nofify user $receiver is neither an email address, a user nor a group";
	    }
	}
    }
    \@new_receivers;
}

1;

__END__

=head1 NAME

WebEditor::OldFeatures::Notify - notify functions

=head1 SYNOPSIS

    use mixin 'WebEditor::OldFeatures::Notify';

    $oldcontroller_objecy->notify($action, ...);

=head1 DESCRIPTION

=head2 SETUP NOTIFY

To setup the notify function in the web.editor, just add the line

    notify => { all => "admin" },

to the features list in F<WEprojectinfo.pm>. The hash consists of
B<action> keys and B<receivers> values. The receivers may be a single
string or an array of strings. These strings should either denote

=over

=item an email address

An internet email address (recognized with a C<@> in it).

=item a user

A web.editor user.

=item a group

A web.editor role/group. A user specification has always priority over
a same-named role/group.

=back

to send the notify message to. The actions may be:

=over

=item all

All notifyable actions.

=item release

A release action (e.g. saving and releasing a page, releasing a folder
recursively).

=item publish

A publish action (manually from a user or automatically from a daemon)
of the wohole site.

=item folderpublish

A publish action for a folder only.

=item deletepage

A page was deleted.

=back

Another example:

    notify => { "all" => "admin",
                "publish" => ["chiefeditor", 'webmaster@example.com'],
	      },

=head1 AUTHOR

Slaven Rezic

=cut
