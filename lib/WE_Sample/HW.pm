# -*- perl -*-

#
# $Id: HW.pm,v 1.3 2003/01/16 14:29:11 eserte Exp $
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

package WE_Sample::HW;

$^W = 0; # XXX too much problems with HyperWave::CSP

use base qw(WE::DB);
use WE::Obj;

WE::DB->use_databases(qw/HWObj HWContent/);
WE::Obj->use_classes(':all');

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, $hwhost, $hwport, %args) = @_;
    my $self = {};
    bless $self, $class;

    $self->ObjDB(WE::DB::HWObj->new($self,
				    -hwhost => $hwhost,
				    -hwport => $hwport,
				    %args,
				   ));
    $self->ContentDB(WE::DB::HWContent->new($self));
    $self;
}

sub identify {
    my($self, $user, $pw) = @_;
    my $objdb = $self->ObjDB;
    my $server = HyperWave::CSP->new($objdb->HWHost, $objdb->HWPort,
				     $user, $pw);
    if ($server) {
	$objdb->HW($server);
	$self->CurrentUser($user);
	1;
    } else {
	0;
    }
}

1;

__END__

=head1 NAME

WE_Sample::HW - sample web.editor interface to the Hyperwave server

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

