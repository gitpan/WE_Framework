# -*- perl -*-

#
# $Id: FolderObj.pm,v 1.4 2003/12/04 22:24:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Obj::FolderObj;

use base qw(WE::Obj);

=head1 NAME

WE::Obj::FolderObj - base class for folder-like objects

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a base class for all objects containing other objects.

DocObj instances can hold the additional attribute B<Head> with the Id
of the "index.html" file of this folder. B<IndexDoc> is a synonym for
B<Head>.

=cut

__PACKAGE__->mk_accessors(qw(Head));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 0 }

sub IndexDoc { shift->Head(@_) }

1;

__END__


=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

