# -*- perl -*-

#
# $Id: Root.pm,v 1.23 2005/01/28 08:44:07 eserte Exp $
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

package WE_Singlesite::Root;

=head1 NAME

WE_Singlesite::Root - a simple implementation for a site

=head1 SYNOPSIS

    $root = new WE_Singlesite::Root -rootdir => $root_directory_for_database;

=head1 DESCRIPTION

A simple instantiation for C<WE::DB>.

=head1 ADDITIONAL MEMBERS

=over

=item RootDir

The root directory for all databases.

=back

=head1 OVERRIDEABLE METHODS

=over 4

=item ObjDBClass

By default L<WE::DB::Obj>

=item UserDBClass

By default L<WE::DB::User>

=item ContentDBClass

By default L<WE::DB::Content>

=item OnlineUserDBClass

By default L<WE::DB::OnlineUser>

=item NameDBClass

By default L<WE::DB::Name>

=item ObjDBFile

By default F<objdb.db>

=item UserDBFile

By default F<userdb.db>

=item ContentDBFile

By default F<content>

=item OnlineUserDBFile

By default F<onlinedb.db>

=item NameDBFile

By default F<name.db>

=item SerializerClass

By default Data::Dumper

=item DBClass

By default DB_File

=back

=head1 METHODS

=over 4

=cut

use base qw(WE::DB);
# Unfortunately old projects rely on this "use":
use WE::Obj;

__PACKAGE__->mk_accessors(qw/RootDir/);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, %args) = @_;
    my $self = {};
    bless $self, $class;

    my $db_dir = delete $args{-rootdir};
    die "No -rootdir given" if !defined $db_dir;
    $self->RootDir($db_dir);
    my $readonly = defined $args{-readonly} ? delete $args{-readonly} : 0;
    my $autocreate = delete $args{-autocreate} || 0;
    if (!-d $db_dir && $autocreate) {
	require File::Path;
	File::Path::mkpath($db_dir);
    }
    if (!$readonly && !-w $db_dir) {
	die "The -rootdir $db_dir is not writable (needed for lockfiles etc.)";
    }
    my $connect    = $args{-connect};
    my $writeonly  = defined $args{-writeonly}  ? delete $args{-writeonly} : 0;
    my $locking    = defined $args{-locking}    ? delete $args{-locking} : 1;
    my $serializer = defined $args{-serializer} ? delete $args{-serializer} : $self->SerializerClass;
    my $failsafe   = defined $args{-failsafe}   ? delete $args{-failsafe} : 0;
    my $db         = defined $args{-db}         ? delete $args{-db} : $self->DBClass;
    my $cache      = defined $args{-cache}      ? delete $args{-cache} : 0;

    if ($self->ObjDBClass) {
	$self->use_databases($self->ObjDBClass);
	eval {
	    $self->ObjDB
		($self->ObjDBClass->new($self, "$db_dir/" . $self->ObjDBFile,
					-connect    => $connect,
					-readonly   => $readonly,
					-writeonly  => $writeonly,
					-locking    => $locking,
					-serializer => $serializer,
					-db         => $db,
					-cache      => $cache,
				       ));

	    WE::Obj->use_classes(':all');
	};
	if ($@) {
	    $failsafe ? warn $@ : die $@;
	}
    }

    if ($self->UserDBClass) {
	$self->use_databases($self->UserDBClass);
	eval {
	    $self->UserDB
		($self->UserDBClass->new($self, "$db_dir/" . $self->UserDBFile,
					 -connect   => $connect,
					 -readonly  => $readonly,
					 -writeonly => $writeonly,
					));
	};
	if ($@) {
	    $failsafe ? warn $@ : die $@;
	}
    }

    if ($self->ContentDBClass) {
	$self->use_databases($self->ContentDBClass);
	eval {
	    $self->ContentDB
		($self->ContentDBClass->new($self, "$db_dir/" . $self->ContentDBFile,
					    -connect   => $connect,
					    -readonly  => $readonly,
					    -writeonly => $writeonly,
					   ));
	};
	if ($@) {
	    $failsafe ? warn $@ : die $@;
	}
    }

    if ($self->OnlineUserDBClass) {
	$self->use_databases($self->OnlineUserDBClass);
	eval {
	    $self->OnlineUserDB
		($self->OnlineUserDBClass->new($self, "$db_dir/" . $self->OnlineUserDBFile,
					       -connect   => $connect,
					       -readonly  => $readonly,
					       -writeonly => $writeonly,
					      ));
	};
	if ($@) {
	    $failsafe ? warn $@ : die $@;
	}
    }

    if ($self->NameDBClass) {
	$self->use_databases($self->NameDBClass);
	eval {
	    $self->NameDB
		($self->NameDBClass->new($self, "$db_dir/" . $self->NameDBFile,
					 -connect   => $connect,
					 -readonly  => $readonly,
					 -writeonly => $writeonly,
					));
	};
	if ($@) {
	    $failsafe ? warn $@ : die $@;
	}
    }

    $self;
}

sub ObjDBClass        { "WE::DB::Obj"        }
sub UserDBClass       { "WE::DB::User"       }
sub ContentDBClass    { "WE::DB::Content"    }
sub OnlineUserDBClass { "WE::DB::OnlineUser" }
sub NameDBClass       { "WE::DB::Name"       }

sub ObjDBFile         { "objdb.db"           }
sub UserDBFile        { "userdb.db"          }
sub ContentDBFile     { "content"            }
sub OnlineUserDBFile  { "onlinedb.db"        }
sub NameDBFile        { "name.db"            }

sub SerializerClass   { "Data::Dumper"       }
sub DBClass           { "DB_File"            }

sub disconnect {
    my($self) = @_;
    $self->ObjDB->disconnect;
    $self->UserDB->disconnect;
#    $self->ContentDB->disconnect;
    $self->OnlineUserDB->disconnect;
    $self->NameDB->disconnect;
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    my $u = $self->UserDB;
}

sub export_db {
    my($self, %args) = @_;
    $args{-as} = 'perl' if !exists $args{-as};
    $args{-db} = [qw(ObjDB UserDB OnlineUserDB NameDB)] if !exists $args{-db};
    if ($args{-as} eq 'perl') {
	my @obj;
	my @varnames = @{$args{-db}};
	foreach my $db (@{$args{-db}}) {
	    my $db_obj = eval '$self->'.$db; die $@ if $@; # for 5.005
	    if ($db_obj->can('Connected') && !$db_obj->Connected) {
		die "The export_db method requires a permanent connection to the database $db";
	    }
	    push @obj, $db_obj->{DB};
	}
	require Data::Dumper;
	my $dd = Data::Dumper->new([@obj], [@varnames]);
	$dd->Indent(0); # for Windows
	return $dd->Dump;
    } else {
	die "Export type $args{-as} is not implemented";
    }
}

sub import_db {
    my($self, %args) = @_;
    $args{-as} = 'perl' if !exists $args{-as};
    die "No -string option given" if !defined $args{-string};
    require Safe;
    my $pkg = __PACKAGE__ . '::Safe';
    my $cpt = Safe->new($pkg);
    $cpt->reval($args{-string});
    foreach my $db (qw(ObjDB UserDB OnlineUserDB NameDB)) {
	my $db_obj = eval '$self->'.$db; die $@ if $@; # for 5.005
	my $o = eval "\$${pkg}::$db";
	if (defined $o) {
	    %{$db_obj->{DB}} = %$o;
	}
    }
}

sub get_permissions {
    my($self) = @_;
    require WE::Util::Permissions;
    my $new_location = $self->RootDir . "/../etc/permissions";
    my $permfile = $self->RootDir . "/permissions";
    if (-e $permfile) {
	warn "Detected permissions file at old location. Please consider to move the file to $new_location";
    } elsif (-e $new_location) {
	$permfile = $new_location;
    } else {
	warn "Cannot find permissions file in $new_location";
    }
    my $perm = WE::Util::Permissions->new(-file => $permfile);
    $self->{Permissions} = $perm;
}

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
    my $permissions = $self->{Permissions};
    if (!$permissions) {
	$permissions = $self->get_permissions;
    }
    my $path;
    if (defined $obj_id) {
	$path = $self->ObjDB->pathname($obj_id);
    }
    my $group = $self->CurrentGroups;
    $permissions->is_allowed
	(-user => $user,
	 ($group && ref $group && @$group > 0 ? (-group => $group) : ()),
	 (defined $path ? (-page => $path) : ()),
	 -process => $action,
	);
}

sub is_releasable_page {
    my($self, $obj) = @_;
    my $objdb = $self->ObjDB;
    $objdb->objectify_params($obj);
    my $release_state = $obj->Release_State || "";
    return 0 if $release_state eq 'inactive';
    return 1;
}

=item release_page($obj, %args)

Release the page with object $obj. Pass the object, not the id. If the
value of the C<-useversioning> argument is true, then do a check-in of
the released objects (see also C<useversioning> in C<WEprojectinfo>).
The arguments C<Title>, C<VisibleToMenu> and C<Rights> are used, if
defined, to set the respective object members.

=cut

sub release_page {
    my $self = shift;
    my $newobj = shift;
    my %args = @_;
    if (!defined $newobj) {
	die "Object is missing in release_page";
    }
    my $objdb = $self->ObjDB;
    my $useversioning = delete $args{-useversioning};
    my $pid = $newobj->Id;

    my $versionedobj;
    if ($useversioning) {
	$versionedobj = $objdb->ci($pid);
	$versionedobj->{Release_State} = "released";
	# XXX have to re-get the object because ci changed it!
	$newobj = $objdb->get_object($pid);
    }
    $newobj->{Release_State} = "released";

    foreach my $copykey (qw(Title VisibleToMenu Rights)) {
	if (defined $args{$copykey}) {
	    $versionedobj->{$copykey} = $args{$copykey} if $versionedobj;
	    $newobj->{$copykey}       = $args{$copykey};
	}
    }
    $objdb->replace_object($versionedobj) if $versionedobj;
    $objdb->replace_object($newobj);

    $newobj;
}

1;

__END__

=back

=head1 HISTORY

Historically this module preloaded the standard ObjDB, UserDB,
ContentDB, OnlineUserDB and NameDB classes with C<<
WE::DB->use_databases >>. Since about 2005-01-23 this modules are only
preloaded if actually needed (that is, on construction time). This
means that some inherited modules which depend on this preloading
should do the preloading itself now.

=head1 CAVEATS

See incompatible change in L</HISTORY>.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>.

=cut

