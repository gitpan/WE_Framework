# -*- perl -*-

#
# $Id: LangDoc.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package WE::Obj::LangDoc;

use base qw(WE::Obj::Doc);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 1 }

1;

__END__

=head1 NAME

WE::Obj::LangDoc - a language-specific version of a document

=head1 SYNOPSIS


=head1 DESCRIPTION

This is used in WE::Obj::LangCluster collections.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj::Doc>.

=cut

