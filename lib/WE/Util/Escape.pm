# -*- perl -*-

#
# $Id: Escape.pm,v 1.2 2004/12/13 23:19:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sf.net/projects/we-framework/
#

package WE::Util::Escape;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use vars qw(%uri_escapes);
for (0..255) {
    $uri_escapes{chr($_)} = sprintf("%%%02X", $_);
}

sub uri_escape {
    my($text) = @_;
    return undef unless defined $text;
    # Default unsafe characters.  RFC 2732 ^(uric - reserved)
    $text =~ s/([^A-Za-z0-9\-_.!~*'()])/$uri_escapes{$1} || sprintf "%%u%04x", ord($1)/ge;
    $text;
}

1;
