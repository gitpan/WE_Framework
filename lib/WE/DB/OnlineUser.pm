# -*- perl -*-

#
# $Id: OnlineUser.pm,v 1.8 2003/12/16 15:21:23 eserte Exp $
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

package WE::DB::OnlineUser;

use base qw/WE::DB::Base/;

use strict;
use vars qw($VERSION $TIMEOUT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors(qw/Timeout DBFile/);

use DB_File;

$TIMEOUT = 10*60;

=head1 NAME

WE::DB::OnlineUser - methods for users who are currently online

=head1 SYNOPSIS

    new WE::DB::OnlineUser $rootdb, $databasefilename, -timeout => 30*60;

=head1 DESCRIPTION

This class holds methods for users who are currently online. Users may
login and logout and should in intervals smaller than C<$TIMEOUT> ping
back to the server so they signal that they are still logged in.

All timeouts are in seconds. The default timeout is 10 minutes.

=head2 CONSTRUCTOR new($class, $root, $file, %args)

Usually called from C<WE::DB>.

=cut

sub new {
    my($class, $root, $file, %args) = @_;
    my $self = {};
    bless $self, $class;
    $self->DBFile($file);

    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};

    my $flags;
    if ($args{-readonly}) {
	$flags = O_RDONLY;
    } elsif ($args{-writeonly}) {
	$flags = O_RDWR;
    } else {
	$flags = O_RDWR|O_CREAT;
    }

    if (!defined $args{-connect} || $args{-connect} ne 'never') {
	tie %{$self->{DB}}, "DB_File", $file, $flags, 0664
	    or die("Can't tie database $file: $!");
	$self->Connected(1);
    }
    if (defined $args{-timeout}) {
	$self->Timeout($args{-timeout});
    } else {
	$self->Timeout($TIMEOUT);
    }
    $self;
}

=head2 METHODS

=over 4

=item login($user)

Log in the specified C<$user> to the online user database.

=cut

sub login {
    my($self, $user) = @_;
    $self->{DB}{$user} = time;
}

=item logout($user)

Log out the specified C<$user> from the online user database.

=cut

sub logout {
    my($self, $user) = @_;
    delete $self->{DB}{$user};
}

=item check_logged($user, [$timeout], [$result])

Check whether the specified user is still logged in. Return either a
true or false value. The C<$timeout> parameter is optional. If
C<$result> is specified, it has to be a reference to a scalar value
and will hold the exact result string (e.g. "Not logged in", "Timed
out" or "Logged in") after the method returns. Some usage examples:

    $bool = $onlineuserdb->check_logged("eserte");
    $bool = $onlineuserdb->check_logged("eserte", undef, \$result);
    print "Result is: $result\n";
    $bool = $onlineuserdb->check_logged("eserte", 10*60, \$result);

=cut

sub check_logged {
    my($self, $user, $timeout, $result) = @_;
    $timeout = $self->Timeout unless defined $timeout;
    my $last_check = $self->{DB}{$user};
    if (!defined $last_check) {
	$$result = "Not logged in" if ref $result eq 'SCALAR';
	return 0;
    }
    if ($last_check+$timeout < time) {
	$$result = "Timed out" if ref $result eq 'SCALAR';
	return 0;
    }
    $$result = "Logged in" if ref $result eq 'SCALAR';
    1;
}

=item ping($user)

The C<$user> marks himself as alive in the online database.

=cut

sub ping {
    my($self, $user) = @_;
    $self->{DB}{$user} = time;
}

=item cleanup([$timeout])

Delete all non-logged-in users from the online user database. The
C<$timeout> parameter is optional.

=cut

sub cleanup {
    my($self, $timeout) = @_;
    # XXX locking?
    my(@todel);
    while(my($user) = each %{$self->{DB}}) {
	if (!$self->check_logged($user, $timeout)) {
	    push @todel, $user;
	}
    }
    foreach (@todel) {
	$self->logout($_);
    }
}

=item delete_db_contents

Delete all database contents

=cut

sub delete_db_contents {
    my $self = shift;
    my(@todel) = keys %{$self->{DB}};
    foreach (@todel) {
	delete $self->{DB}{$_};
    }
}

=item disconnect

Disconnect the database. No further access on the database may be done.

=cut

sub disconnect {
    my $self = shift;
    eval {
	untie %{ $self->{DB} };
    };warn $@ if $@;
}

# XXX del:
#  =item delete_db

#  Delete the database completely (including the disk file).

#  =cut

#  sub delete_db {
#      my $self = shift;
#      unlink $self->DBFile;
#  }

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB::User>.

=cut

