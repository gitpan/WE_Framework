# -*- perl -*-

#
# $Id: AuthUnix.pm,v 1.1 2005/01/28 08:40:41 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

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
