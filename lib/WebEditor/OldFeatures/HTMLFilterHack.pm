# -*- perl -*-

#
# $Id: HTMLFilterHack.pm,v 1.1 2004/12/09 17:36:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::HTMLFilterHack;

=head1 NAME

WebEditor::OldFeatures::HTMLFilterHack - replace the TT html filter

=head1 SYNOPSIS

In .../OldController.pm:

    use WebEditor::OldFeatures::HTMLFilterHack;

In the templates:

    [% variable | html %]

=head1 DESCRIPTION

This is a untested hack to replace the standard "html" filter with a
version creating numeric entities.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use Template::Filters qw();
use HTML::Entities qw();

no warnings 'redefine'; # XXX 5.005 compat missing

*Template::Filters::html_filter = sub {
    HTML::Entities::encode_entities_numeric($_[0]);
};
