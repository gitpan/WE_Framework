# -*- perl -*-

#
# $Id: Root_GDBM.pm,v 1.1 2004/02/14 10:22:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Singlesite::Root_GDBM;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw(WE_Singlesite::Root);

sub DBClass { "GDBM_File" }

1;

__END__
