# -*- perl -*-

#
# $Id: SiteRestr.pm,v 1.1 2005/01/23 01:40:06 eserte Exp $
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

package WE::Obj::SiteRestr;

use base qw(WE::Obj::Folder);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 1 }

sub insertable_types { [qw(WE::Obj::Folder
			   WE::Obj::Sequence
			   WE::Obj::LangCluster
			   WE::Obj::Doc
			  )] }

1;

__END__

=head1 NAME

WE::Obj::SiteRestr - the root object of a site

=head1 SYNOPSIS


=head1 DESCRIPTION

This is the restricted version of L<WE::Obj::Site>.

=head1 HISTORY

This was the former C<WE::Obj::Site>. 

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj::Folder>.

=cut

