# -*- perl -*-

#
# $Id: AuthenWE.pm,v 1.9 2005/03/14 10:15:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package Apache::AuthenWE;

use strict;
use Apache::Constants ':common';
$Apache::AuthenWE::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub handler {

    require WE::DB;

    my $r = shift;
    my($res, $sent_pwd) = $r->get_basic_auth_pw;
    return $res if $res; #decline if not Basic

    my $name = $r->connection->user;

    if ($name eq "") {
        $r->note_basic_auth_failure;
        $r->log_reason("Apache::AuthenWE - no username given", $r->uri);
        return AUTH_REQUIRED;
    }

    # load apache config vars
    my $dir_config = $r->dir_config;

    my %args;
    my $rootclass  = $dir_config->get('WE_RootClass');
    my $rootdir    = $dir_config->get('WE_RootDir');
    my $logoutuser = $dir_config->get('WE_Authen_LogoutUser');
    my $ignoreuser = $dir_config->get('WE_Authen_IgnoreUser');

    if (defined $logoutuser && $logoutuser ne "") {
	return OK if $logoutuser eq $name;
    }

    if (defined $ignoreuser && $ignoreuser ne "") {
	$r->note_basic_auth_failure;
	return AUTH_REQUIRED if $ignoreuser eq $name;
    }

    if (defined $rootclass) { $args{-class} = $rootclass }
    if (defined $rootdir) { $args{-rootdir} = $rootdir }
    $args{-readonly} = 1;
    $args{-locking} = 0;

    my $rootdb;
    eval {
	$rootdb = WE::DB->new(%args);
	if (!$rootdb) {
	    die "Can't get db with args %args";
	}
	if (!$rootdb->UserDB) {
	    die "No user database";
	}
    };
    if ($@) {
	$r->note_basic_auth_failure;
	$r->log_reason("Apache::AuthenWE - $@", $r->uri);
	return AUTH_REQUIRED;
    }

    my $identified;
    eval {
	$identified = $rootdb->identify($name, $sent_pwd);
    };
    if ($@ || !$identified) {
	$r->note_basic_auth_failure;
	my $msg = "Apache::AuthenWE - Can't identify as $name";
	if ($@) {
	    $msg .= " - $@";
	}
	$r->log_reason($msg, $r->uri);
	return AUTH_REQUIRED;
    }

    my $requires = $r->requires;
    my $userdb = $rootdb->UserDB;
    for my $req (@$requires) {
	my($require, @list) = split /\s+/, $req->{requirement};

	#ok if user is one of these users
        if ($require eq "user") {
            return OK if grep $name eq $_, @list;
        }
        #ok if user is simply authenticated
        elsif ($require eq "valid-user") {
            return OK;
        }
        elsif ($require eq "group") {
	    foreach my $group (@list) {
		if ($userdb->is_in_group($rootdb->CurrentUser, $group)) {
		    return OK;
		}
	    }
        }
    }

    $r->note_basic_auth_failure;
    $r->log_reason("Apache::AuthenWE - user authentified, but not in require list", $r->uri);
    return AUTH_REQUIRED;
}

1;

__END__

=head1 NAME

Apache::AuthenWE - mod_perl WE_Framework authentication module

=head1 SYNOPSIS

    <Directory /foo/bar>
    AuthName "WE_Framework Authentication"
    AuthType Basic

    # This seems to be necessary because of the Authz Handler
    AuthGroupFile /dev/null

    # Put the paths to the WE_Framework and web.editor project classes here
    <Perl>
        push @INC, "/shared/httpd/project/WE_Framework/lib",
                   "/shared/httpd/project/lib";
    </Perl>

    # define WE_Framework class and root directory
    PerlSetVar WE_RootClass WE_Sample::Root
    PerlSetVar WE_RootDir /home/e/eserte/public_html/sample/wwwroot/cgi-bin/we_data
    # Support for the logout user hack (not working yet)
    #PerlSetVar WE_Authen_LogoutUser logoutuser
    #PerlSetVar WE_Authen_IgnoreUser invalid

    PerlAuthenHandler Apache::AuthenWE
    PerlAuthzHandler Apache::AuthenWE

    # Who is allowed to see the pages?
    require user admin
    #require user ich admin chiefeditor
    #require group chiefeditor author
    #require valid-user

    </Directory>

These directives can also be used in the <Location>, <LocationMatch>
or <Files> directives or in an .htaccess file, assuming AllowOverride
is not set to none.

=head1 DESCRIPTION

This module implements Apache authentification through the use of
C<WE_Framework>.

=head2 THE LOGOUT USER HACK

By defining the C<WE_Authen_LogoutUser> mod_perl variable support for
the I<logout user hack> is turned on. The user specified in this
variable is always authentified, regardless of the password value. For
this user, the backend application is responsible to show some kind of
logout screen.

The C<WE_Authen_IgnoreUser> variable holds the name of a user which is
never authentified, but an authentification attempt is not logged. The
existance of such a user name may be necessary for the web.editor
system.

=head1 AUTHOR

Slaven Rezic - eserte@users.sourceforge.net

=head1 SEE ALSO

L<Apache>.

=cut

