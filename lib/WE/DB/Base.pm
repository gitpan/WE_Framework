# -*- perl -*-

#
# $Id: Base.pm,v 1.6 2004/10/04 19:21:10 eserte Exp $
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

=head1 NAME

WE::DB::Base - base class for all database classes

=head1 SYNOPSIS


=head1 DESCRIPTION

=head2 METHODS

=over

=cut

package WE::DB::Base;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(Root Connected));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class) = @_;
    my $self = {};
    bless $self, $class;
}

=item connect_if_necessary($sub)

Connect to the database, if there is not a database connection yet,
and execute the supplied subroutine C<$sub>. The return value of
C<$sub> will be returned by C<connect_if_necessary>. Exceptions are
also forwarded to the caller, but after the connection is closed, if
needed.

=cut

sub connect_if_necessary {
    my($self, $sub) = @_;
    my $connected = $self->Connected;
    my $do_disconnect;
    if (!$connected) {
	$self->connect;
	$do_disconnect=1;
    }
    my $wantarray = wantarray;
    my @r;
    eval {
	if ($wantarray) {
	    @r = $sub->();
	} else {
	    $r[0] = $sub->();
	}
    };
    my $err = $@;
    if ($do_disconnect) {
	$self->disconnect;
    }
    if ($err) {
	require Carp;
	Carp::croak($err);
    }
    if ($wantarray) {
	@r;
    } else {
	$r[0];
    }
}

=item disconnect

Disconnect the database. No further access on the database may be done.

=cut

sub disconnect {
    my $self = shift;
    if ($self->Connected) {
	eval {
	    untie %{ $self->{DB} };
	};warn $@ if $@;
	$self->Connected(0);
    }
}

=item delete_db

Delete the database completely, including the disk file.

=cut

sub delete_db {
    my $self = shift;
    unlink $self->DBFile;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

