# -*- perl -*-

#
# $Id: AuthPOP3.pm,v 1.2 2005/02/03 00:06:28 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

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

__END__

=head1 NAME

WE::DB::ComplexUser::AuthPOP3 - ComplexUser database authentication via POP3

=head1 DESCRIPTION

Use a POP3 server to authenticate the user against. The user object
should define the additional members C<Auth_POP3_Host> for the POP3
server to use and C<Auth_POP3_User> for the POP3 user (the user object
Username is used if C<Auth_POP3_User> is undefined).

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<WE::DB::ComplexUser>.

=cut
