# -*- perl -*-

#
# $Id: AuthUnix.pm,v 1.2 2005/02/03 00:06:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE::DB::ComplexUser::AuthUnix;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WE::DB::ComplexUser';

# This works only on system without shadow passwords!

sub identify_Unix {
    my($self, $user, $password) = @_;

    my $unix_user = $user->{Auth_Unix_User} || $user->Username;
    warn "Try unix authentication with user=$unix_user...\n" if $DEBUG;

    my(undef, $pwd, $uid) = getpwnam($unix_user);
    if (!defined $uid) {
	warn "The unix user <$unix_user> is undefined" if $DEBUG;
	return 0;
    }
    
    if (crypt($password, $pwd) eq $pwd) {
	return 1;
    } else {
	warn "Password incorrect" if $DEBUG;
	return 0;
    }
}

1;

__END__

=head1 NAME

WE::DB::ComplexUser::AuthUnix - ComplexUser database authentication via unix passwd

=head1 DESCRIPTION

Use normal Unix passwd authentication to authenticate the user
against. The user object could define the additional member
C<Auth_Unix_User> to define the Unix user (the user object Username is
used if C<Auth_Unix_User> is undefined).

B<NOTE>: Most modern Unices (e.g. Linux, *BSD) have "shadow" files
which hold the passwords and which are only accessible for root. This
means this module is most cases only works if running as root.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<WE::DB::ComplexUser>.

=cut
