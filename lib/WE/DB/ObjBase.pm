# -*- perl -*-

#
# $Id: ObjBase.pm,v 1.16 2004/02/19 22:26:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

WE::DB::ObjBase - base class for WE_Framework object databases

=head1 SYNOPSIS

    use base qw(WE::DB::ObjBase);

=head1 DESCRIPTION

=cut

package WE::DB::ObjBase;
use base qw(WE::DB::Base);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

use WE::Util::Date;

=head2 METHODS

Please see also L<WE::DB::Base> for inherited methods.

=over

=cut

=item children($object_id)

Like children_ids, but return objects.

=cut

sub children {
    my($self, $obj_id) = @_;
    map {
	my $o = $self->get_object($_);
	if (!$o) {
	    my $obj_id = $obj_id;
	    my $child_id = $_;
	    $self->idify_params($obj_id, $child_id);
	    warn "Inconsistency in children method call for objid=$obj_id detected: child with objid=$child_id non-existent. Consider to run we_fsck. Error";
	    ();
	} else {
	    $o;
	}
    } $self->children_ids($obj_id);
}

=item parents($object_id)

Like parent_ids, but return parent objects instead.

=cut

sub parents {
    my($self, $obj_id) = @_;
    map {
	my $o = $self->get_object($_);
	if (!$o) {
	    warn "Inconsistency in parents($obj_id) detected";
	    ();
	} else {
	    $o;
	}
    } $self->parent_ids($obj_id);
}

=item versions($object_id)

Like version_ids, but return version objects instead.

=cut

sub versions {
    my($self, $obj_id) = @_;
    map {
	my $o = $self->get_object($_);
	if (!$o) {
	    warn "Inconsistency in versions($obj_id) detected";
	    ();
	} else {
	    $o;
	}
    } $self->version_ids($obj_id);
}

=item objectify_params($id_or_obj, ...)

For each parameter in the list, change the argument to be an object of
the database.

=cut

sub objectify_params {
    my $self = shift;
    foreach (@_) {
	if (!UNIVERSAL::isa($_, "WE::Obj")) {
	    $_ = $self->get_object($_);
	}
    }
}

=item idify_params($id_or_obj, ...)

For each parameter in the list, change the argument to be an object
identifier if it was an object, or leave it as it was.

=cut

sub idify_params {
    my $self = shift;
    foreach (@_) {
	if (UNIVERSAL::isa($_,"WE::Obj")) {
	    $_ = $_->Id;
	}
    }
}

=item replace_content_from_file($object_id, $filename)

Like replace_content, but get contents from file.

=cut

sub replace_content_from_file {
    my($self, $objid, $filename) = @_;
    $self->idify_params($objid);
    open(F, $filename) or die "Can't open file $filename: $!";
    local $/ = undef;
    my $new_content = <F>;
    close F;
    $self->replace_content($objid, $new_content);
}

=item walk($object_id, $sub_routine, @args)

Traverse the object hierarchie, beginning at the object with id
C<$object_id>. For each object, C<$sub_routine> is called with the
object id and optional C<@args>. Note that the subroutine is B<not>
called for the start object itself.

If there's no persistent connection to the database (i.e. the database
was not accessed with -connect => 1), then using
B<connect_if_necessary> is advisable for better performance.

Here are some examples for using walk.

Get the number of descendent objects from the folder with Id
C<$folder_id>. The result is in the C<$obj_count> variable:

    my $obj_count = 0;
    $objdb->walk($folder_id, sub {
		     my($id, $ref) = @_;
		     $$ref++;
		 }, \$obj_count);
    warn "There are $obj_count objects in $folder_id\n";

Get all released descendant objects. The released state should be
recorded in the Release_State member. The resulting list is a flat
array.

    my @results;
    $objdb->walk($folder_id, sub {
		     my($id) = @_;
                     my $obj = $objdb->get_object($id);
		     if ($obj->Release_State eq 'released') {
			 push @results, $obj;
		     }
		 });
    # The released objects are in @results.

If you want to break the recursion on a condition, simply use an
C<eval>-block and C<die> on the condition. See the source code of
C<name_to_objid> method for an example.

C<walk> uses postorder traversal, that is, subtrees first, node later.

Note that the start object itself is not included in the traversal and
the subroutine will not be called for it.

The returned value of the last callback called with be returned.

=item walk_preorder($object_id, $sub_routine, @args)

This is like C<walk>, but uses preorder instead of postorder, that is,
node first, children later.

Note that the start object itself will be included in the traversal.
This is different from the C<walk> method.

In preorder walk, the traversal of subtrees can be avoided by setting
the global variable C<$WE::DB::Obj::prune> to a true value.

=cut

sub walk {
    my($self, $objid, $sub_routine, @args) = @_;
    my $ret;
    $self->idify_params($objid);
    if (!UNIVERSAL::isa($sub_routine, 'CODE')) {
	die "Second parameter of walk should be code reference";
    }
    for my $sub_obj_id ($self->children_ids($objid)) {
	$self->walk($sub_obj_id, $sub_routine, @args);
	$ret = $sub_routine->($sub_obj_id, @args);
    }
    $ret;
}

sub walk_preorder {
    my($self, $objid, $sub_routine, @args) = @_;
    my $ret;
    $self->idify_params($objid);
    if (!UNIVERSAL::isa($sub_routine, 'CODE')) {
	die "Second parameter of walk_preorder should be code reference";
    }

    {
	local $WE::DB::Obj::prune;
	$ret = $sub_routine->($objid, @args);
	return $ret if $WE::DB::Obj::prune;
    }

    for my $sub_obj_id ($self->children_ids($objid)) {
	$ret = $self->walk_preorder($sub_obj_id, $sub_routine, @args);
    }
    $ret;
}

# XXX Document, and implement walk_up_prepostorder when needed!
sub walk_prepostorder {
    my($self, $objid, $pre_sub_routine, $post_sub_routine, @args) = @_;
    my $ret;
    $self->idify_params($objid);
    if (!UNIVERSAL::isa($pre_sub_routine, 'CODE') ||
	!UNIVERSAL::isa($post_sub_routine, 'CODE')) {
	die "Second and third parameters of walk_prepostorder should be code references";
    }

    {
	local $WE::DB::Obj::prune;
	$ret = $pre_sub_routine->($objid, @args);
	return $ret if $WE::DB::Obj::prune;
    }

    for my $sub_obj_id ($self->children_ids($objid)) {
	$ret = $self->walk_prepostorder($sub_obj_id, $pre_sub_routine, $post_sub_routine, @args);
    }

    {
	local $WE::DB::Obj::prune;
	$ret = $post_sub_routine->($objid, @args);
	return $ret if $WE::DB::Obj::prune;
    }

    $ret;
}

=item walk_up($object_id, $sub_routine, @args)

Same as C<walk>, but walk the tree up, that is, traverse all parents
from the object to the root.


=item walk_up_preorder($object_id, $sub_routine, @args)

Same as C<walk_up>, but traverse in pre-order, that is, from the
object to the root. Note that the object itself is also included in
the traversal.

In preorder walk, the further traversal of parents can be avoided by
setting the global variable C<$WE::DB::Obj::prune> to a true value.

=cut

sub walk_up {
    my($self, $objid, $sub_routine, @args) = @_;
    my $ret;
    $self->idify_params($objid);
    if (!UNIVERSAL::isa($sub_routine, 'CODE')) {
	die "Second parameter of walk_up should be code reference";
    }
    for my $p_obj_id ($self->parent_ids($objid)) {
	$self->walk_up($p_obj_id, $sub_routine, @args);
	$ret = $sub_routine->($p_obj_id, @args);
    }
    $ret;
}

sub walk_up_preorder {
    my($self, $objid, $sub_routine, @args) = @_;
    my $ret;
    $self->idify_params($objid);
    if (!UNIVERSAL::isa($sub_routine, 'CODE')) {
	die "Second parameter of walk_up_preorder should be code reference";
    }

    local $WE::DB::Obj::prune;
    $ret = $sub_routine->($objid, @args);
    return $ret if $WE::DB::Obj::prune;

    for my $p_obj_id ($self->parent_ids($objid)) {
	if (defined $p_obj_id) {
	    $ret = $self->walk_up_preorder($p_obj_id, $sub_routine, @args);
	}
    }
    $ret;
}

=item whole_tree([$objid])

Return the whole (sub)tree of C<$objid>. If C<$objid> is not given,
then return the whole tree. The elements of the tree are structured in
a nested array. Each element is a hash of the following elements: Id,
Title and isFolder.

=cut

sub whole_tree {
    my($self, $objid, $tree) = @_;
    $objid = $self->root_object->id if !defined $objid;
    $tree  = [] if !$tree;
    my $obj = $self->get_object($objid);
    if (!$obj) {
	warn "Can't get object $objid!";
	return;
    }
    push @$tree, {Id=>$obj->Id, Title=>$obj->Title, isFolder=>$obj->is_folder};
    my @children_ids = $self->children_ids($objid);
    if (@children_ids) {
	my $child_tree = [];
	foreach my $cid (@children_ids) {
	    $self->whole_tree($cid, $child_tree);
	}
	push @$tree, $child_tree;
    }
    $tree;
}

=item _undirty($object)

Return the object with all Dirty flags set to 0.

=cut

sub _undirty {
    my($self, $obj) = @_;
    $self->objectify_params($obj);
    $obj->Dirty(0);
    $obj->DirtyAttributes(0);
    $obj->DirtyContent(0);
    $self->replace_object($obj);
}

=item is_locked($object_id)

Return true if the object is locked by someone else.

=cut

sub is_locked {
    my($self, $obj) = @_;
    $self->objectify_params($obj);
    return 0 if !defined $obj->LockedBy || $obj->LockedBy eq '';
    return 0 if $obj->LockedBy eq $self->Root->CurrentUser;
    if ($obj->LockType eq 'SessionLock') {
	if ($self->Root->OnlineUserDB) {
	    my $r = $self->Root->OnlineUserDB->check_logged($obj->LockedBy);
	    if (!$r) {
		$self->unlock($obj); # XXX -force => 1 ???
	    }
	    return $r;
	} else {
	    return 0;
	}
    }
    return 1 if ($obj->LockType eq 'PermanentLock'); # XXX probably check for existing user?
    warn "Unknown lock type @{[ $obj->LockType ]}, assumed locked";
    1;
}

=item lock($object_id, -type => $lock_type)

Lock the object C<$object_id>. Only single objects can be locked (no
folder hierarchies). Locking must be handled in the client by using
C<is_locked()>. The C<$lock_type> may have the following values:

=over 4

=item SessionLock

This lock should only be valid for this session. If the user closes
the session (either by a logout or by closing the browser window),
then the lock will be invalidated.

=item PermanentLock

This lock lasts over session ends.

=back

Return the object itself.

Now, it should be checked programmatically whether the lock can be set
or not (by looking at the value is_locked). It is not clear what is
the right solution, because there are version control systems where
breaking locks is possible (RCS).

=cut

sub lock {
    my($self, $obj_id, %args) = @_;
    die "Lock -type is missing" if !$args{-type};
    die "Valid Lock types are SessionLock and PermanentLock"
	unless $args{-type} =~ /^(Session|Permanent)Lock$/;
    $self->idify_params($obj_id);
    my $obj = $self->get_object($obj_id);
    $obj->LockedBy($self->Root->CurrentUser);
    $obj->LockType($args{-type});
    $obj->LockTime(epoch2isodate());
    $self->replace_object($obj);
}

=item unlock($object_id)

Unlock the object with id C<$object_id>.

Return the object itself.

Now, it should be checked programmatically whether the lock can be
unset or not (by looking at the value is_locked). It is not clear what
is the right solution, because there are version control systems where
breaking locks is possible (RCS).

=cut

sub unlock {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $obj = $self->get_object($obj_id);
    $obj->LockedBy(undef);
    $obj->LockType(undef);
    $obj->LockTime(undef);
    $self->replace_object($obj);
}

=item pathobjects($object_or_id [, $parent_obj])

For the object or id C<$object_or_id>, the object path is returned.
This is similar to the C<pathname> method, but returns a list of
objects instead of a pathname.

If C<$parent_obj> is given as a object, then the returned pathname is
only a partial path starting from this parent object.

=cut

sub pathobjects {
    my($self, $obj, $parent_obj) = @_;
    $self->objectify_params($obj);
    if (defined $parent_obj && $obj->Id eq $parent_obj->Id) {
	return ();
    }
    my @parents = $self->parent_ids($obj->Id);
    if (@parents) {
	($self->pathobjects($parents[0], $parent_obj), $obj);
    } else {
	($obj);
    }
}

=item pathobjects_with_cache($object_or_id [, $parent_obj], $cache_hash_ref)

As C<pathobjects>, but also use a cache for a faster access.

=cut

sub pathobjects_with_cache {
    my($self, $obj, $parent_obj, $cache) = @_;
    if (!ref $obj && exists $cache->{$obj}) { # get by id
	return @{ $cache->{$obj} };
    }
    $self->objectify_params($obj);
    return () if !$obj;
    my $objid = $obj->Id;
    if (exists $cache->{$objid}) {
	return @{ $cache->{$objid} };
    }
    if (defined $parent_obj && $objid eq $parent_obj->Id) {
	$cache->{$obj->Id} = [];
	return ();
    }
    my @parents = $self->parent_ids($objid);
    if (@parents) {
	if (exists $cache->{$parents[0]}) {
	    (@{ $cache->{$parents[0]} }, $obj);
	} else {
	    my @parent_parents = $self->pathobjects_with_cache($parents[0], $parent_obj);
	    $cache->{$parents[0]} = [@parent_parents];
	    (@parent_parents, $obj);
	}
    } else {
	($obj);
    }
}

=item name_to_objid($name)

Return the object id for the object containing the Attribute
C<Name=$name>. If there is no such object, undef is returned. Note: This
method may or may not be efficient, depending whether there is an
index database (C<NameDB>) or not.

=cut

sub name_to_objid {
    my($self, $name) = @_;
    my $objid;
    if ($self->Root->NameDB) {
	$objid = $self->Root->NameDB->get_id($name);
	return $objid if defined $objid;
    }
    # for backward compatibility (database without name.db)
    eval {
	local $SIG{__DIE__};
	$self->walk($self->root_object->Id, sub {
			my($id) = @_;
			my $obj = $self->get_object($id);
			if (defined $obj->Name && $obj->Name eq $name) {
			    $objid = $obj->Id;
			    die "Found";
			}
		    });
    };
    $objid;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB::Base>, L<WE::DB>.

=cut
