# -*- perl -*-

#
# $Id: WWWAuth.pm,v 1.3 2004/04/08 14:24:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sourceforge.net/projects/we-framework
#

package WebEditor::OldFeatures::WWWAuth;

=head1 NAME

WebEditor::OldFeatures::WWWAuth -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

sub wwwauthedit {
    my $self = shift;
    my $root = $self->Root;
    my($all_users_js, $all_groups_js);
    my $c = $self->C;
    if ($c->project->features->{"wwwauth"}) {
	my $u = $self->get_wwwauth_user_db;
	require Data::JavaScript;
	$all_users_js = join "\n", Data::JavaScript::jsdump
	    ("all_users",
	     [ map { $u->get_user($_) } sort $u->get_all_users ]
	    );
	# XXX output of get_all_groups is wrong!
	$all_groups_js = join "\n", Data::JavaScript::jsdump
	    ("all_groups",
	     [ map { +{ groupname => $_ } } sort $u->get_all_groups ]
	    );
    } else {
	$all_users_js = "all_users = [];\n";
	$all_groups_js = "all_groups = [];\n";
    }

    $self->_tpl("bestwe", "we_wwwauthedit.tpl.html",
		{
		 'message'       => undef,
		 'all_users_js'  => $all_users_js,
		 'all_groups_js' => $all_groups_js,
		}
	       );
}

sub update_auth_files {
    my $self = shift;
    my(%args) = @_;
    my $v = $args{-verbose};
    # XXX do I have to check for -userdb option?
    my $c = $self->C;
    my $userdb = $self->get_wwwauth_user_db;
    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    require WE::Util::Htaccess;
    require WE::Util::Htpasswd;
    require WE::Util::Htgroup;
    for my $lang (@{ $c->project->sitelanguages }) {
	my $dir = $c->paths->pubhtmldir . "/html/$lang";
	my $passwd = "$dir/.htpasswd";
	my $group  = "$dir/.htgroup";
	my $access = "$dir/.htaccess";
	warn "Creating user passwd file $passwd...\n" if $v;
	WE::Util::Htpasswd::create($passwd, $userdb);
	warn "Creating group file $group...\n" if $v;
	WE::Util::Htgroup::create($group, $userdb);
	warn "Creating access file $access...\n" if $v;
	WE::Util::Htaccess::create($access, $objdb,
				   -authname => $c->project->name,#longname? XXX
				   -authuserfile => $passwd,
				   -authgroupfile => $group,
				   -inherit => 1,
 				   -getaliases => sub {
 				       # XXX where to supply -now parameter?
 				       $self->get_alias_pages($_[0]);
 				   },
				   #XXX -add errordocument, see pod
				  );
    }
}

sub get_wwwauth_user_db {
    my $self = shift;
    my $c = $self->C;
    my($type, $userdb) = split /:/, $c->project->features->{"wwwauth"};
    if ($type ne "db") {
	die "Only support for wwwauth database db";
    }
    my $u = $self->get_custom_userdb($userdb);
    $u;
}

1;
