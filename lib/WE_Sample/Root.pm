# -*- perl -*-

#
# $Id: Root.pm,v 1.7 2005/02/03 00:06:29 eserte Exp $
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

package WE_Sample::Root;

=head1 NAME

WE_Sample::Root - a sample implementation for a site

=head1 SYNOPSIS

    $root = new WE_Sample::Root -rootdir => $root_directory_for_database;

=head1 DESCRIPTION

A sample instantiation for C<WE::DB>. This is mainly used for the
WE_Framework test suite.

=head1 METHODS

=over 4

=cut

use base qw(WE_Singlesite::Root);
use WE::Obj;

WE::Obj->use_classes(':all');

WE::DB->use_databases(qw/Obj User Content OnlineUser Name/);

#WE::DB->use_databases(qw/Obj ComplexUser Content OnlineUser Name/);
#sub UserDBClass { "WE::DB::ComplexUser" }

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

=item is_allowed($action, $object_id)

Return a true value if the current user is allowed to do C<$action> on
object C<$object_id>.

Currently are these actions defined:

=over 4

=item release

The user is allowed to release a document ("freigeben").

=item publish

The user is allowed to publish a site.

=item change-folder

The user is allowed to do folder manipulation, that is, he is allowed
to add or delete folders.

=item change-doc

The user is allowed to do document manipulation, that is, he is
allowed to add, edit or delete documents.

=back

If there is no current user, then always a false value is returned.

=cut

sub is_allowed {
    my($self, $action, $obj_id) = @_;
    my $user = $self->CurrentUser;
    return 0 if !$user;
    if ($action =~ /^(release|publish|change-folder)$/) {
	return $self->UserDB->is_in_group($user,"chiefeditors") ||
	       $self->UserDB->is_in_group($user,"admins");
    } elsif ($action eq 'change-doc') {
	return $self->UserDB->is_in_group($user,"editors") ||
	       $self->UserDB->is_in_group($user,"chiefeditors") ||
	       $self->UserDB->is_in_group($user,"admins");
    } elsif ($action eq 'everything') {
	return $self->UserDB->is_in_group($user,"admins");
    } else {
	die "Unknown action $action";
    }
    0;
}

=item get_released_children($folder_id)

Return all folders and released children as an array of objects.

=cut

sub get_released_children {
    my($self, $folder_id) = @_;
    my @children = $self->ObjDB->children($folder_id);
    my @res;
    for my $o (@children) {
	if ($o->is_folder) {
	    push @res, $o;
	} else {
	    my $r = $self->get_released_object($o->Id);
	    push @res, $r if defined $r;
	}
    }
    @res;
}

=item get_released_object($object_id)

Return the last released version for C<$object_id>. If there is no
released version yet, return C<undef>.

=cut

sub get_released_object {
    my($self, $obj_id) = @_;
    my $obj = $self->ObjDB->get_object($obj_id);
    die "Can't get object with id $obj_id" if !$obj;
    foreach my $v_id (reverse $self->ObjDB->version_ids($obj_id)) {
	my $v = $self->ObjDB->get_object($v_id);
	if ($v->Release_State eq 'released') {
	    return $v;
	}
    }
    undef;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>, L<WE_Singlesite::Root>.

=cut

