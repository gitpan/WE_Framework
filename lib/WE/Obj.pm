# -*- perl -*-

#
# $Id: Obj.pm,v 1.10 2005/01/31 08:28:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2005 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Obj;

=head1 NAME

WE::Obj - base object class for the web editor framework

=head1 SYNOPSIS

   This is an abstract class.

=head1 DESCRIPTION

For member attributes there are accessors defined. To get the value of
a member named B<Id>, use:

    $object->Id;

To set the value of a member use:

    $object->Id($new_value);

Below is a list of member attributes which can be defined for each
object. The semantics apply to the L<WE::DB::Obj|WE::DB::Obj>
database.

=over 4

=item Id

The identifier for this object. Normally, this identifier is numeric
(but it does not have to). The normal user should not change the Id.

=item Title

The title for this object. This is usually a normal string. If you
want to set language-dependent titles, then look at
L<WE::Util::LangString>.

=item Basename

An optional basename for this object. For backends using a
pathname-like scheme, this can be used to construct the basename. See
L<Net::FTPServer::WE_DB::Server>.

=item Name

An optional name for this object. This name should be unique in the
database and will be used for name-based queries.

=item Keywords

Optional keywords for this object. This is usually a normal string. If you
want to set language-dependent keywords, then look at
L<WE::Util::LangString>.

=item TimeCreated

The time of the creation of the object. This attribute is set
automatically and should not be changed. The returned value is an ISO
date. See L<WE::Util::Date> for conversion functions for ISO dates.

=item TimeModified

The time of the last modification of the object. Both attribute
modification and content modification are taken into account. Like in
C<TimeCreated>, the returned value is an ISO date.

=item Owner

This is the owner of the object. The owner is set automatically when
creating the object (see L<WE::DB/CurrentUser>). See L</NOTES> below
for more information.

=item DocAuthor

This is the original author of the object. This should be set only if
the original author differs from the technical Owner of the object.

=item Rights

For now, the value for the B<Rights> member is a freely definable. Its
value is not used nor it is inherited to other objects.

=item TimeOpen

This member can be set to an ISO date to indicate the start of
publication for the object.

=item TimeExpire

This member can be set to an ISO date to indicate the end of
publication for the object.

=item Version_Owner

This member is only set for versions and for checked out objects. It
holds the user who made this version. This member is set
automatically.

=item Version_Time

This member is only set for versions and for checked out objects. It
holds the time when this version is made. This member is set
automatically.

=item Version_Comment

This member is only set for versions and for checked out objects. It
holds the (optional) log message (or comment) for this version.

=item Version_Number

This member is only set for versions and for checked out objects. It
holds the version number for this version. Normally version numbers
begin at "1.0" and are incremented by 0.1 (that is, the next would be
"1.1", "1.2" and so on), but version numbers are not necessarily
numbers.

=item Version_Parent

This member is only set for versions and for checked out objects. It
holds the Id of the original object belonging to this version.

=item Release_State

The following values are possible:

=over

=item released

The object is released.

=item inactive

The object should never be released.

=item modified

The object was modified since the last release or it was never
released.

=back

=item Release_*

The attributes Release_Author, Release_Flow, Release_Publishers,
Release_ReviewedBy, and Release_TargetFolder are
defined, but there is not functionality for these.

=item LockedBy

Holds the user who is locking this object.

=item LockType

The LockType may be B<PermanentLock> or B<SessionLock>. A permanent
lock is valid over sessions. A session lock is only valid for the
session of the locking user. If the locking user logs out (or the
system can determine by some other means that the user is not logged
in --- see L<WE::DB::OnlineUser>), then the lock is not valid anymore.

=item Dirty

Indicates that the object is changed after the last check in. This is
the combination of B<DirtyAttributes> and B<DirtyContent>.

=item DirtyAttributes

Indicates that the attributes of the object changed after the last
check in.

=item DirtyContent

Indicates that the content of the object changed after the last check
in.

=back

Other custom attributes may be set by accessing the object as a hash:

    $object->{My_Attribute} = ["my value1", "my value2"];

As you can see, the value may also be a complex perl data structure.
It is a good idea to use a prefix (like "My_" in the sample above) to
minimize the chance of name clashes.

For other standard attributes, look at the documentation of the sub
classes of WE::Obj.

=head2 METHODS

=over 4

=cut

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors
    (qw(Id Title Basename Name Keywords
	TimeCreated TimeModified Owner DocAuthor Rights TimeOpen TimeExpire
	Version_Owner Version_Time Version_Comment Version_Number
	Version_Parent
	Release_Author Release_Flow Release_Publishers Release_ReviewedBy
	Release_State Release_TargetFolder
	LockedBy LockType LockTime
	Dirty DirtyAttributes DirtyContent));

use strict;
use vars qw($VERSION @all_classes);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

@all_classes = qw(Sites Site Folder LangCluster Sequence Doc LangDoc);

sub new {
    my($class, %args) = @_;
    my $self = {%args};
    bless $self, $class;
}

=item instantiable

Return true if the object is instantiable (e.g. only folders and
documents).

=cut

sub instantiable { 0 }

=item insertable_types

Return an array reference of class names which are insertable into
this object. Applies only for folder-like objects.

=cut

sub insertable_types { [] }

=item use_classes(@classes)

Load into perl all given classes. C<:all> means: load all known
classes.

=cut

sub use_classes {
    my($self, @classes) = @_;
    foreach my $class (@classes) {
	# allow abbreviations
	if ($class !~ /^WE::Obj/ && $class !~ /^:/) {
	    $class = "WE::Obj::$class";
	}
	if ($class eq ':all') {
	    push @classes, @all_classes;
	    next;
	}
	eval "require $class; $class->import";
	die $@ if $@;
    }
}

=item object_is_insertable($obj)

Return true if the given object is insertable.

=cut

sub object_is_insertable {
    my($self, $obj) = @_;
    foreach (@{$self->insertable_types}) {
	return 1 if $obj->isa($_) || $_ eq ':all';
    }
    0;
}

=item clone

Clone the given object.

=cut

sub clone {
    my($self) = @_;
    if (eval { local $SIG{__DIE__}; require Storable; 1 }) {
	local $Storable::forgive_me = 1;
	Storable::dclone($self);
    } else {
	no strict 'vars'; # ignore $obj_copy
	require Data::Dumper;
	my $dd = new Data::Dumper([$self],['obj_copy']);
	my $cloned = eval $dd->Dump;
	die $@ if $@;
	$cloned;
    }
}

=item is_doc, is_folder, is_site

Return true if the object is a document, folder or site.

=cut

sub is_doc      { $_[0]->isa('WE::Obj::DocObj') }
sub is_folder   { $_[0]->isa('WE::Obj::FolderObj') }
sub is_site     { $_[0]->isa('WE::Obj::Site') }

=item is_sequence

Return true if the object is a sequence. Remember that a Sequence is
always a FolderObj, so the return value of C<is_folder> will also be
true.

=cut

sub is_sequence { $_[0]->isa('WE::Obj::Sequence') }

=item field_is_date($fieldname)

Return true if the given field should be treated as a date/time field.

=cut

sub field_is_date {
    my($self, $field) = @_;
    $field =~ /^(TimeCreated|TimeModified|TimeOpen|TimeExpire|Version_Time|LockTime)$/ ? 1 : 0;
}

=item field_is_user($fieldname)

Return true if the given field should be treated as a username field.

=cut

sub field_is_user {
    my($self, $field) = @_;
    $field =~ /^(Owner|Version_Owner|Release_Author|Release_ReviewedBy|LockedBy)$/ ? 1 : 0;
}

=item field_is_user($fieldname)

Return true if the given field should not be edited (e.g. Id field).

=cut

sub field_is_not_editable {
    my($self, $field) = @_;
    $field =~ /^(Id)$/ ? 1 : 0;
}

=item is_time_restricted($now)

Return true if the object is restricted via C<TimeOpen> and
C<TimeExpire>. To adjust the current time, set C<$now> to a unix epoch
time in seconds.

=cut

sub is_time_restricted {
    my($self, $now) = @_;
    if (!defined $now) {
	require WE::Util::Date;
	$now = WE::Util::Date::epoch2isodate(time);
    }

    my $timeopen   = $self->TimeOpen   || undef;
    return 1 if (defined $timeopen && $timeopen gt $now);
    my $timeexpire = $self->TimeExpire || undef;
    return 1 if (defined $timeexpire && $timeexpire lt $now);
    0;
}

1;

__END__

=back

=head1 NOTES

The L</Owner> is normally the Username of the owner, but depending on
database needs the engine may interpret this value as the user Id.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut
