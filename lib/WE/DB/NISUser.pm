# -*- perl -*-

#
# $Id: NISUser.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package WE::DB::NISUser;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use Net::NIS;

sub new {
    my($class, $root, %args) = @_;
    my $self = {};
    bless $self, $class;
    $self->{Domain} = scalar Net::NIS::yp_get_default_domain();
    $self;
}

sub identify {
    my($self, $user, $password) = @_;
    my $ret = 0;
    my($status, $entry) = Net::NIS::yp_match($self->{Domain}, "passwd.byname", $user);
    return 0 if $status;
    my $hash = (split /:/, $entry)[1];
    crypt($password, $hash) eq $hash ? 1 : 0;
}

sub get_fullname {
    my($self, $user) = @_;
    my($status, $entry) = Net::NIS::yp_match($self->{Domain},"passwd.byname", $user);
    return 0 if $status;
    (split /:/, $entry)[4];
}

sub user_exists {
    my($self, $user) = @_;
    my($status, $entry) = Net::NIS::yp_match($self->{Domain},"passwd.byname", $user);
    $status ? 0 : 1;
}

sub add_user {
    my($self, $user, $password, $fullname) = @_;
    die "Not implemented with " . __PACKAGE__;
}

sub update_user {
    my($self, $user, $password, $fullname,$groups) = @_;
    die "Not implemented with " . __PACKAGE__;
}

sub delete_user {
    my($self, $user) = @_;
    die "Not implemented with " . __PACKAGE__;
}

sub is_in_group {
    my($self, $user, $group) = @_;
    my($status, $entry) = Net::NIS::yp_match($self->{Domain},"group.byname", $group);
    return 0 if $status;
    scalar grep { $user eq $_ } split(/,/, (split(/:/, $entry))[3]);
}

sub get_groups {
    my($self, $user) = @_;
    my($status, $values) = Net::NIS::yp_all($self->{Domain},"group.byname");
    return () if !$values;
    my @groups;
    while(my($group, $entry) = each %$values) {
	my $users = (split(/:/, $entry))[3];
	if (defined $users) {
	    if (grep { $user eq $_ } split(/,/, $users)) {
		push @groups, $group;
	    }
	}
    }
    @groups;
}

sub get_user {
    my($self, $user) = @_;
    my($status, $entry) = Net::NIS::yp_match($self->{Domain},"passwd.byname", $user);
    if ($status == 0) {
	my @things = split /:/, $entry;
	my @groups = $self->get_groups($user);
	return {'groups' => \@groups,
		'username' => $user,
		'password' => $things[1],
		'fullname' => $things[4],
	       };
    }
    0;
}

sub add_group {
    my($self, $user, $group) = @_;
    die "Not implemented with " . __PACKAGE__;
}

sub delete_group {
    my($self, $user, $delgroup) = @_;
    die "Not implemented with " . __PACKAGE__;
}

sub get_users_of_group {
    my($self, $group) = @_;
    my @users;
    foreach my $usr (keys %{$self->{DB}}) {
	if ( $self->is_in_group($usr,$group) ) { push(@users,$usr); }
    }
    return @users;
}

sub get_all_users {
    my($self) = @_;
    my($status, $values) = Net::NIS::yp_all($self->{Domain},"passwd.byname");
    keys %$values;
}

sub get_all_groups {
    my($self) = @_;
    my($status, $values) = Net::NIS::yp_all($self->{Domain},"group.byname");
    keys %$values;
}

1;

__END__

=head1 NAME

WE::DB::NISUser - Webeditor interface to NIS user databases.

=head1 SYNOPSIS

    my $u = WE::DB::NISUser->new(undef);

=head1 DESCRIPTION

See L<WE::DB::User> for a list of methods.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB::User>, L<WE::DB>

=cut

