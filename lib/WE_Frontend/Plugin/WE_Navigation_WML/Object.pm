# -*- perl -*-

#
# $Id: Object.pm,v 1.1 2004/02/18 18:03:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::WE_Navigation_WML::Object;

use base qw(WE_Frontend::Plugin::WE_Navigation::Object);

use strict;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub ext { ".wml" }

1;
