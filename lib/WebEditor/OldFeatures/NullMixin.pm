# -*- perl -*-

#
# $Id: NullMixin.pm,v 1.1 2005/01/27 16:13:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sourceforge.net/projects/we-framework
#

package WebEditor::OldFeatures::NullMixin;

=head1 NAME

WebEditor::OldFeatures::NullMixin -

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a template for a new mixin.

=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

# add mixin'ed methods here

1;
