# -*- perl -*-

#
# $Id: Admin.pm,v 1.30 2004/12/23 17:54:02 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldController::Admin;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.30 $ =~ /(\d+)\.(\d+)/);

package WebEditor::OldController;

sub admin {
    my $self = shift;
    my $c = $self->C;
    $self->check_login;
    if (!param("nohttpheader")) {
	# XXX find better solution --- do not output HTML here!
	print "<html><body bgcolor='#ffffff' onload='if (top.mainpanel && top.mainpanel.setwait) top.mainpanel.setwait(0);'>";
    }
    my $root = $self->Root;
    if (!$root->is_allowed([qw/admin useradmin release publish/])) {
	print "Not allowed!";
	print "</body>";
	exit;
    }

    my $msg;

    param('action', '') if !defined param('action');

    # XXX this block should be generated automatically somehow
    if (param('action') eq "makemenu") {
	if ($self->can("makemenu")) {
	    $self->makemenu;
	    $msg = "Menus/Navigation erfolgreich neu gebaut."; # XXX lang
	} else {
	    die "No makemenu method available";
	}
    } elsif (param('action') eq "makehtml") {
	require WebEditor::OldFeatures::MakeOnePageHTML;
	my $lang = param("lang");
	return WebEditor::OldFeatures::MakeOnePageHTML::makeonepagehtml_send
	    ($self, -debug => $c->debug, -lang => $lang);
    } elsif (param('action') eq "makeps") {
	# XXX toc etc. should be supplied by form params
	require WebEditor::OldFeatures::MakePS;
	my $lang = param("lang");
	return WebEditor::OldFeatures::MakePS::makeps_send
	    ($self, -debug => $c->debug, -lang => $lang, -toc => 1);
    } elsif (param('action') eq "makepdf") {
	# XXX toc etc. should be supplied by form params
	require WebEditor::OldFeatures::MakePDF;
	my $lang = param("lang");
	return WebEditor::OldFeatures::MakePDF::makepdf_send
	    ($self, -debug => $c->debug, -lang => $lang, -toc => 1);
    } elsif (param('action') eq 'timebasedupdatehtml') {
	return $self->timebasedupdatehtml;
    } elsif (param('action') eq 'do_timebasedupdatehtml') {
	return $self->do_timebasedupdatehtml;
    } elsif (param('action') eq 'info') {
	require mixin; mixin::->import("WebEditor::OldFeatures::SystemInfo");
	print $self->system_info_as_html;
    } elsif (param('action') eq 'groupadmin') {
	# XXX automatically load the admingroup mixin if not yet loaded?
	return $self->groupadmin;
    }

    if ($self->can("admin_modules")) {
	$self->admin_modules; # XXX do not supply $c anymore!
    }

    $self->_tpl("bestwe", "we_admin.tpl.html", { message => $msg });
}

sub admin_modules {
    my $self = shift;
#XXX how to access features in WebEditor::OldFeatures cleanly?
    if (param('action') eq "htdig") {
	require mixin;
	mixin->import("WebEditor::OldFeatures::AdminHtdig");
	$self->admin_htdig_module;
    }
}

######################################################################
#
# publish all released pages
#
sub publish {
    my $self = shift;
    my $root = $self->Root;
    $self->check_login;
    if (!$root->is_allowed(["admin","publish"])) {
	die "This function is only allowed for users with admin or publish rights\n";
    }

    print "<html><head><title>Sync Site</title></head><body onload='top.mainpanel.setwait(0);'>";
    print "<h2>Copying HTML files to the live server ...</h2>";
    print "<pre>\n";
    my $publish_done;
    if (param("simulate")) {
	if ($self->can("do_simulate_publish")) {
	    $self->do_simulate_publish(-verbose => 2); # XXX make configurable?
	} else {
	    print "Eine Simulation ist nicht möglich...<br>\n";
	}
    } else {
	if ($self->can("do_publish")) {
	    $self->do_publish(-verbose => 2); # XXX drop to 1? make configurable?
	    $publish_done++;
	} else {
	    my $fe = $self->FE;
	    if (!$fe || !$fe->can("publish")) {
		print "Publishing is not configured, aborting...\n";
	    } else {
		$fe->publish(-verbose => 2); # XXX drop to 1?
		$publish_done++;
	    }
	}
    }
    print "</pre>\n";
#    print '<a href="'.$c->paths->cgiurl.'/we_redisys.cgi?goto=main&editorlang='.$self->EditorLang.'">Go back</a>';
    print "</body></html>\n";
    $self->notify("publish") if $publish_done && $self->can("notify");
} #### sub publish END

sub timebasedupdatehtml {
    my $self = shift;
    my $root = $self->Root;
    $self->check_login;
    if (!$root->is_allowed(["admin","release"])) {
	die "This function is only allowed for users with admin or release rights\n";
    }
    $self->_tpl("bestwe", "we_admin_timebasedupdatehtml.tpl.html");
}

sub do_timebasedupdatehtml {
    my $self = shift;
    my $root = $self->Root;
    $self->check_login;
    if (!$root->is_allowed(["admin","release"])) {
	die "This function is only allowed for users with admin or release rights\n";
    }
    my $date = param("date");
    require WE::Util::Date;
    my $isodate = WE::Util::Date::epoch2isodate(WE::Util::Date::isodate2epoch(param("date")));
    my $dir = $isodate;
    $dir =~ s/[^a-zA-Z0-9]/_/g;
    $dir = "/tmp/" . $self->C->project->name . "_$dir";
    mkdir $dir, 0755;
    mkdir "$dir/html", 0755;
    warn "Update wird für das Datum $isodate in $dir gemacht";
    $self->updatehtml(-pubhtmldir => $dir,
		      -now => $isodate);
}

######################################################################

sub linkchecker {
    my $self = shift;
    # no access control...

    # This is a long-running process without need to access the database:
    $self->Root->disconnect;
    require WE_Frontend::LinkChecker;
    local $WE_Frontend::LinkChecker::VERBOSE = $WE_Frontend::LinkChecker::VERBOSE = 1;
    my $c = $self->C;
    my @urls;
    foreach my $lang (@{ $c->project->sitelanguages }) {
	push @urls, $c->paths->absoluteurl . "/html/$lang/index.html";
    }
    my $lc = WE_Frontend::LinkChecker->new
	(-url => \@urls,
#	 -follow => [$c->paths->absoluteurl],
	 -restrict => [$c->paths->absoluteurl],
	);
#    print $lc->check_html;
    require Template;
    my $t = Template->new($self->TemplateConf);
    print $lc->check_tt($t, "we_linkchecker_result.tpl.html",
			$self->TemplateVars);
    exit 0;
}

######################################################################

sub checkreleased {
    my $self = shift;
    $self->check_login;
    my $root = $self->Root;
    if (!$root->is_allowed(["admin","release"])) {
	die "This function is only allowed for users with admin or release rights\n";
    }

    my $unreleased_objects = [];

    my $objdb = $root->ObjDB;
    $objdb->walk_preorder
	($objdb->root_object->Id, sub {
	     my $objid = shift;
	     my $o = $objdb->get_object($objid);
	     if (defined $o->Release_State && $o->Release_State eq 'inactive') {
		 # Skipping inactive folder/document
		 $WE::DB::Obj::prune = 1; # cut off subtree
		 return;
	     }
	     if ($o->is_doc && (!defined $o->Release_State || $o->Release_State ne 'released')) {
		 push @$unreleased_objects,
		     {Title => langstring($o->Title, $self->EditorLang),
		      Id    => $o->Id,
		     };
	     }
	 });

    my $templatevars = $self->TemplateVars;
    $templatevars->{'unreleased'} = $unreleased_objects;
    $self->_tpl("bestwe", "we_check_released.tpl.html");
}


sub releasepages {
    my $self = shift;
    $self->check_login;
    my $root = $self->Root;
    if (!$root->is_allowed("admin")) {
	die "This function is only allowed for users with admin rights\n";
    }
    my $released_objects   = [];
    my $unreleased_objects = [];
    my $objdb = $root->ObjDB;
    $objdb->connect_if_necessary(sub {
        for my $id (param("pageid")) {
	    my $obj = $objdb->get_object($id);
	    if (!$obj) {
		warn "Object with id $id unavailable for release.\n";
		push @$unreleased_objects, {Id => $id};
		next;
	    }
	    my $descr = {Title => langstring($obj->Title, $self->EditorLang),
			 Id    => $obj->Id};
	    $root->release_page($obj);
	    push @$released_objects, $descr;
	}
    });

    my $templatevars = $self->TemplateVars;
    $templatevars->{'released'}   = $released_objects;
    $templatevars->{'unreleased'} = $unreleased_objects;
    $self->_tpl("bestwe", "we_release_result.tpl.html");
}

######################################################################
#
# Simple User Management Interface SUMI
#
# XXX use ->msg!
sub useradmin {
    my $self = shift;
    # XXX problem: if root changes his own password...
    $self->check_login;
    my $root = $self->Root;
    if (!$root->is_allowed(["admin","useradmin"])) {
	print "Not allowed! Back to <a href='javascript:history.back()'>admin</a> page";
	exit;
    }
    my $c = $self->C;
    my $templatevars = $self->TemplateVars;

    my $u;
    my $useradmindb = param('useradmindb') || '';
    my $userdb_prop;
    if ($useradmindb eq '') {
	$u = $root->UserDB;
	if ($root->can('get_userdb_prop')) {
	    $userdb_prop = $root->get_userdb_prop("");
	}
    } else {
	$u = $self->get_custom_userdb($useradmindb);
    }
    if (!$u) {
	$self->error("No userdb for $useradmindb defined");
    }

    my $message;
    my $useradminaction = param('useradminaction');
    my $useradminuser = param('useradminuser');
    my $useradminname = param('useradminname');
    my $useradmingroups = param('useradmingroups');
    my $useradmindeluser = param('useradmindeluser');
    my $useradminpassword1 = param('useradminpassword1');
    my $useradminpassword2 = param('useradminpassword2');

    my $extra_userinfo_update = sub {
	if ($c->project->features->{wwwauth}) {
	    # XXX passing -userdb not necessary anymore?
	    $self->update_auth_files(-verbose => 0, -userdb => $u)
		if $useradmindb && $self->can("update_auth_files");
	}
    };

    my $userinfo_update = sub {
	my %new;
	foreach my $key (param()) {
	    next unless $key =~ /^useradminuser_(.*)/;
	    my $fieldkey = $1;
	    my $val = param($key);
	    $new{$fieldkey} = $val;
	}
	if (keys %new) {
	    my $userobj = $u->get_user_object($useradminuser);
	    @{$userobj}{keys %new} = values %new;
	    $u->set_user_object($useradminuser, $userobj);
	}

	$extra_userinfo_update->();
    };

    $useradminaction = "" if !defined $useradminaction;

    if ($useradminaction eq "adduser") {
	if ($useradminuser =~ /^\s*$/ || ($useradminpassword1 =~ /^\s*$/ && param("useradminuser_AuthType") ne "POP3")) {
	    $message = "<b>Error: no user or password given!</b>";
	} elsif ($useradminpassword1 ne $useradminpassword2) {
	    $message = "<b>Error: two different passwords!</b>";
	} else {
	    if ($u->add_user($useradminuser, $useradminpassword1, $useradminname)) {
		foreach my $grp ( split(/\#/,$useradmingroups) ) {
		    $u->add_group($useradminuser,$grp);
		}
		$userinfo_update->();
		$message = "User $useradminuser successfully added.";
	    } else {
		$message = "<b>Could not add user $useradminuser</b>";
	    }
	}
    } elsif ($useradminaction eq "upduser") {
	if ($useradminpassword1 ne $useradminpassword2) {
	    $message = "<b>Error: two different passwords!</b>";
	} else {
	    if ($useradminpassword1 eq '') {
		undef $useradminpassword1;
	    }
	    if ($u->update_user($useradminuser,$useradminpassword1,$useradminname)) {
		$u->set_groups($useradminuser, split(/\#/,$useradmingroups));
		$userinfo_update->();
		$message = "User $useradminuser successfully updatded.";
		my $userobj;
		if ($userobj = $u->get_user($useradminuser)) {
		    $message = "Updated user information.";
		    $templatevars->{'user'} = $userobj;
		}
	    } else {
		$message = "<b>Could nt update user $useradminuser</b>";
	    }
	}
    } elsif ($useradminaction eq "deluser") {
	if ($u->delete_user($useradmindeluser)) {
	    $extra_userinfo_update->();
	    $message = "User $useradmindeluser successfully deleted.";
	} else {
	    $message = "<b>Could not delete user $useradmindeluser</b>";
	}
    } elsif ($useradminaction eq "edituser") {
	my $userobj;
	if ($userobj = $u->get_user($useradminuser)) {
	    $message = "Please edit user $useradminuser. Leave the password empty to keep the old password.";
	    $templatevars->{'user'} = $userobj;
	} else {
	    $message = "<b>Could not get user data for $useradminuser</b>";
	}
    } else { # newuser
	$message = "Please edit new user.";
    }
    my @allusers = $u->get_all_users();
    @allusers = sort @allusers;
    my @allgroups = ($userdb_prop && $userdb_prop->allgroups
		     ? @{ $userdb_prop->allgroups }
		     : ($root->can("get_all_groups")
			? $root->get_all_groups
			: ($u->can("get_all_groups")
			   ? $u->get_all_groups
			   : ()
			  )
		       )
		    );
    @allgroups = sort @allgroups;
    $templatevars->{'allgroups'} = \@allgroups;

    # process Template
    $templatevars->{'allusers'} = \@allusers;
    $templatevars->{'useradmindb'} = $useradmindb;
    $templatevars->{'message'} = $message;
    $templatevars->{'headline'} = $self->msg($useradmindb eq 'wwwuser' ? "cap_webuseradmin" : "cap_useradmin");
    if ($c->project->features->{groupadmin}) {
	$templatevars->{'groupadminbutton'} = $self->msg($useradmindb eq 'wwwuser' ? "cap_webgroupadmin" : "cap_groupadmin");
    }
    $self->_tpl("bestwe", "we_useradmin.tpl.html");
}

1;

__END__
