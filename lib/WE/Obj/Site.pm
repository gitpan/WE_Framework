# -*- perl -*-

#
# $Id: Site.pm,v 1.5 2005/01/23 01:42:02 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2005 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Obj::Site;

use base qw(WE::Obj::Folder);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 1 }

sub insertable_types { [':all'] }

1;

__END__

=head1 NAME

WE::Obj::Site - the root object of a site

=head1 SYNOPSIS

This is the unrestricted version of L<WE::Obj::SiteRestr>.

=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj::Folder>.

=cut

