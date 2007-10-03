# -*- perl -*-

#
# $Id: AuthPOP3S.pm,v 1.1 2005/05/11 09:31:01 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::ComplexUser::AuthPOP3S;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WE::DB::ComplexUser';

sub identify_POP3S {
    my($self, $user, $password) = @_;

    my $host     = $user->{Auth_POP3S_Host}; # XXX || $self->default_pop3_host;
    my $pop_user = $user->{Auth_POP3S_User} || $user->Username;

    warn "Try pop3 with host=$host and user=$pop_user...\n" if $DEBUG;

    require Net::POP3S;
    my $pop = Net::POP3S->new($host, Timeout => 10);
    my $ret = $pop->login($pop_user, $password) ? 1 : 0;
    $pop->quit;
    $ret;
}

1;

__END__

=head1 NAME

WE::DB::ComplexUser::AuthPOP3S - ComplexUser database authentication via POP3S

=head1 DESCRIPTION

Use a POP3S server to authenticate the user against. The user object
should define the additional members C<Auth_POP3S_Host> for the POP3S
server to use and C<Auth_POP3S_User> for the POP3S user (the user object
Username is used if C<Auth_POP3S_User> is undefined).

Note that the L<Net::POP3S> module is needed, which cannot be found at
CPAN, but only here:
L<http://www.lugmen.org.ar/~harpo/files/fetchmail/fetchmail.tar.bz2>.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<WE::DB::ComplexUser>, L<Net::POP3>.

=cut
