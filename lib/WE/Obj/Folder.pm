# -*- perl -*-

#
# $Id: Folder.pm,v 1.5 2005/01/23 01:42:02 eserte Exp $
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

package WE::Obj::Folder;

use base qw(WE::Obj::FolderObj);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 1 }

sub insertable_types { [':all'] }

1;

__END__

=head1 NAME

WE::Obj::Folder - an object containing other objects

=head1 SYNOPSIS


=head1 DESCRIPTION

This is the unrestricted version of L<WE::Obj::FolderRestr>.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj::FolderObj>.

=cut

