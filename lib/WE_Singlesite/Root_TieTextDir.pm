# -*- perl -*-

#
# $Id: Root_TieTextDir.pm,v 1.1 2004/02/23 07:27:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Singlesite::Root_TieTextDir;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw(WE_Singlesite::Root);

sub DBClass   { "Tie::TextDir" }
sub ObjDBFile { "objdb.dir"    }

1;

__END__
