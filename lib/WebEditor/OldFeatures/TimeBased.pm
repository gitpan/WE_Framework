# -*- perl -*-

#
# $Id: TimeBased.pm,v 1.1 2004/02/23 07:26:51 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::TimeBased;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with qw(WebEditor::OldController);

sub WebEditor::OldFeatures::TimeBased::Hooks::page_released {
    my($self, $objid) = @_;
    warn "page released hook!";
}

1;

__END__
