# -*- perl -*-

#
# $Id: WE_Navigation_WML.pm,v 1.1 2004/02/18 18:03:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::WE_Navigation_WML;
use base qw(WE_Frontend::Plugin::WE_Navigation);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require WE_Frontend::Plugin::WE_Navigation_WML::Object;

sub Object {
    "WE_Frontend::Plugin::WE_Navigation_WML::Object";
}

1;

__END__

=head1 NAME

WE_Frontend::Plugin::WE_Navigation_WML - specialized navigation plugin

=head1 DESCRIPTION

This is the same as L<WE_Frontend::Plugin::WE_Navigation> just for wml
pages.

=cut

