# -*- perl -*-

#
# $Id: AuthPOP3.pm,v 1.1 2004/12/22 13:54:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::ComplexUser::AuthPOP3;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WE::DB::ComplexUser';

sub identify_POP3 {
    my($self, $user, $password) = @_;

    my $host     = $user->{Auth_POP3_Host}; # XXX || $self->default_pop3_host;
    my $pop_user = $user->{Auth_POP3_User} || $user->Username;

    warn "Try pop3 with host=$host and user=$pop_user...\n" if $DEBUG;

    require Net::POP3;
    my $pop = Net::POP3->new($host, Timeout => 10);
    my $ret = $pop->login($pop_user, $password) ? 1 : 0;
    $pop->quit;
    $ret;
}

1;
