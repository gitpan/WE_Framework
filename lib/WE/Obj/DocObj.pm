# -*- perl -*-

#
# $Id: DocObj.pm,v 1.4 2004/12/21 23:18:04 eserte Exp $
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

package WE::Obj::DocObj;

require WE::Obj;
@ISA = qw(WE::Obj);

=head1 NAME

WE::Obj::DocObj - base class for objects holding content data

=head1 SYNOPSIS

    This is an abstract class.

=head1 DESCRIPTION

This is a base class for all objects containing data.

DocObj instances can hold the additional attribute B<ContentType> with
the MIME type of the document (e.g. "text/html"). Undefined documents
will hold "application/octet-stream".

=cut

__PACKAGE__->mk_accessors(qw(ContentType));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub instantiable { 0 }

# document-like objects cannot hold other objects
sub insertable_types { [] }

1;

__END__


=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

