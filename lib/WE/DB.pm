# -*- perl -*-

#
# $Id: DB.pm,v 1.14 2005/02/03 00:06:26 eserte Exp $
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

package WE::DB;

=head1 NAME

WE::DB - root of web editor database collection

=head1 SYNOPSIS

    $root = new WE::DB

=head1 DESCRIPTION

Instantiate a new root for a web.editor database. This class will
usually be overwritten by a class doing the dirt work of opening the
sub-databases. See L<WE_Singlesite::Root> for an example.

=cut

use base qw(Class::Accessor);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

use vars qw(@DBs);
@DBs = qw(UserDB ObjDB ContentDB LinkDB OnlineUserDB NameDB);

__PACKAGE__->mk_accessors(qw/CurrentUser CurrentGroups/, @DBs);

=head2 CONSTRUCTOR new([%args])

If C<-class =E<gt> Classname> is specified, then a specialized class
constructor will be used (for example C<WE_Sample::Root>). Additional
arguments are passed to this constructor.

=cut

sub new {
    my($class, %args) = @_;
    if ($args{-class}) {
	my $class = delete $args{-class};
	eval "require $class";
	if ($@) {
	    my $err = $@;
	    if (!$class->can("new")) {
		# There's no constructor: it is really a failure...
		die $@;
	    }
	    # else the class is probably a file-less class already defined
	}
	$class->new(%args);
    } else {
	my $self = {};
	bless $self, $class;
    }
}

=head2 METHODS

=over 4

=item use_databases(@classes)

Tell the framework to L<use|perlfunc/"use Module"> the given database
classes. These classes will be automatically loaded.

The classes can be specified as abbreviated names (without a ":" in
the class name), in this case C<WE::DB> is automatically prepended.

The special class name C<:all> represents the classes C<Obj>, C<User>
and C<Content>. Note that these are not really all available databases
in a typical WE system.

=cut

sub use_databases {
    my($self, @classes) = @_;
 TRY_CLASS:
    foreach my $class (@classes) {
	# allow abbreviations
	if (#$class !~ /^WE::DB/ && # XXX remove if harmless
	    $class !~ /:/) {
	    $class = "WE::DB::$class";
	}
	if ($class eq ':all') { # XXX this is not "all"
	    push @classes, qw(Obj User Content);
	    next TRY_CLASS;
	}

	{
	    no strict 'refs';
	    # stolen from base.pm, has_version:
	    my $vglob = ${$class.'::'}{VERSION};
	    if ($vglob && *$vglob{SCALAR}) {
		# class is already loaded
		next TRY_CLASS;
	    }
	}

	eval "require $class; $class->import";
	die $@ if $@;
    }
}

=item login($user, $password)

Identify the user and do a login to the system by putting him to the
OnlineUser database. Return true if everything was right.

=cut

sub login {
    my($self, $user, $password) = @_;
    my $r = $self->identify($user, $password);
    if ($r) {
	$self->OnlineUserDB->login($user) if $self->OnlineUserDB;
    }
    $r;
}

=item logout($user)

Logout the user.

=cut

sub logout {
    my($self, $user) = @_;
    $self->OnlineUserDB->logout($user) if $self->OnlineUserDB;
}

=item identify($user, $password)

Identify $user with $password and return true if the authentification
is successful. Also set the CurrentUser member. This does not make any
changes to the OnlineUser database.

=cut

sub identify {
    my($self, $user, $password) = @_;
    my $r = $self->UserDB->identify($user, $password);
    if ($r) {
	$self->CurrentUser($user);
    }
    $r;
}

=item is_allowed($action, $object_id)

Return a true value if the current user is allowed to do C<$action> on
object C<$object_id>.

This method should be overridden, because it provides no access
control in this form.

=cut

sub is_allowed {
    my($self, $action, $obj_id) = @_;
    my $user = $self->CurrentUser;
    return 0 if !$user;
    warn "The is_allowed() method in WE::DB should be overridden!\n";
    return 1;
}

=item is_releasable_page($obj)

Return true if the given object is releasable. The default
implementation always returns true.

=cut

sub is_releasable_page {
    my($self, $obj) = @_;
    return 1;
}

=item root_object

Return the root object of the underlying object database

=cut

sub root_object {
    my($self) = @_;
    $self->ObjDB->root_object;
}

=item init

Initialize the underlying databases.

=cut

sub init {
    my($self) = @_;

    foreach my $db (@DBs) {
	if (defined $self->{$db} && $self->{$db}->can("init")) {
	    $self->{$db}->init;
	}
    }
}

=item delete_db_contents

Delete the contents from B<all> underlying databases.

=cut

sub delete_db_contents {
    my($self) = @_;

    foreach my $db (@DBs) {
	if (exists $self->{$db} && $self->{$db}->can("delete_db_contents")) {
	    $self->{$db}->delete_db_contents;
	}
    }
}

=item delete_db

Delete B<all> underlying databases. This will also remove the files,
not just the contents as in C<delete_db_contents>.

=cut

sub delete_db {
    my $self = shift;
    foreach my $db (@DBs) {
	if (exists $self->{$db} && $self->{$db}->can("delete_db")) {
	    $self->{$db}->delete_db;
	}
    }
}

=item CurrentUser

Set or get the currently logged in user.

=cut

sub CurrentUser {
    my $self = shift;
    if (@_) {
	$self->{CurrentUser} = $_[0];
	if ($self->UserDB) {
	    $self->CurrentGroups([ $self->UserDB->get_groups($self->{CurrentUser}) ]);
	}
    }
    $self->{CurrentUser};
}

sub CurrentLang {
    my $self = shift;
    if (@_) {
	$self->{CurrentLang} = $_[0];
    } else {
	if ($self->CurrentUser && 0 #$self->CurrentUser->Lang
	   ) {
	    $self->CurrentUser->Lang;
	} else {
	    $self->{CurrentLang};
	}
    }
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Singlesite::Root>, L<WE_Sample::Root>.

=cut

