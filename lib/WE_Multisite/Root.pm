# -*- perl -*-

#
# $Id: Root.pm,v 1.6 2003/12/16 15:21:23 eserte Exp $
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

package WE_Multisite::Root;

=head1 NAME

WE_Multisite::Root - a sample implementation for a multi-site environment

=head1 SYNOPSIS

    $root = new WE_Multisite::Root -rootdir => $root_directory_for_database;

=head1 DESCRIPTION

A sample instantiation for C<WE::DB> for multi-site environments.
There is only one UserDB for the whole system, but there is a number
of independen site databases (ObjDB and ContentDB).

=head1 METHODS

=over 4

=cut

use base qw(WE::DB);
use WE::Obj;

WE::Obj->use_classes(':all');
WE::DB->use_databases(qw/Obj ComplexUser Content OnlineUser Name/);

__PACKAGE__->mk_accessors(qw(DBDir Readonly Locking));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, %args) = @_;
    my $self = {};
    bless $self, $class;

    my $db_dir = delete $args{-rootdir};
    die "No db_dir given" if !defined $db_dir;
    $self->DBDir($db_dir);
    my $readonly = defined $args{-readonly} ? delete $args{-readonly} : 0;
    if (!$readonly) {
	die "$db_dir is not writable" if !-w $db_dir;
    }
    $self->Readonly($readonly);
    my $locking = defined $args{-locking} ? delete $args{-locking} : 1;
    $self->Locking($locking);

    $self->UserDB       (WE::DB::ComplexUser->new($self, "$db_dir/userdb.db"));
    $self->OnlineUserDB (WE::DB::OnlineUser->new($self, "$db_dir/onlinedb.db"));

    $self;
}

sub init {
    die "XXX Reimplementation needed!";
    my $self = shift;
    $self->SUPER::init(@_);
    my $u = $self->UserDB;
}

sub identify {
    die "XXX should I use CurrentUser or another member for the user directories?";
    my $self = shift;
    my $r = $self->SUPER::identify(@_);
    if ($r) {
	my $user = $self->CurrentUser;
	$self->ObjDB(WE::DB::Obj->new($self, $self->DBDir."/$user/objdb.db",
				      #-serializer => 'Storable',
				      -locking => $self->Locking,
				      -readonly => $self->Readonly,
				     ));
	$self->ContentDB(WE::DB::Content->new($self, $self->DBDir."/$user/content"));
	$self->NameDB(WE::DB::Content->new($self, $self->DBDir."/$user/name.db"));
    }
    $r;
}


1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>.

=cut

