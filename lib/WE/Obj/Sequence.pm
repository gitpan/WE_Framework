# -*- perl -*-

#
# $Id: Sequence.pm,v 1.5 2003/12/16 15:21:23 eserte Exp $
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

package WE::Obj::Sequence;

use base qw(WE::Obj::FolderObj);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 1 }

sub insertable_types { [qw(WE::Obj::LangCluster
			   WE::Obj::Doc
			  )] }

1;

__END__

=head1 NAME

WE::Obj::Sequence - a object holding an ordered sequence of objects

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj::FolderObj>.

=cut

