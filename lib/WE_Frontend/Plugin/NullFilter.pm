# -*- perl -*-

#
# $Id: NullFilter.pm,v 1.1 2004/03/25 13:52:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::NullFilter; # <-- change this
use base qw(Template::Plugin::Filter);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::NullFilter - a sample custom filter

=head1 SYNOPSIS

    # In the calling script (normally already done by WebEditor::OldController)
    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    # In the template
    [% USE NullFilter %]
    [% FILTER $NullFilter %]
    ...
    [% END %]
    [% variable | $NullFilter %]

=head1 DESCRIPTION

This filter does nothing, i.e. it copies the input unchanged to the
output. This module serves as a sample filter for own extensions.

=cut

sub filter {
    my($self, $text) = @_;
    # do something interesting with $text
    return $text;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin::Filter>.

=cut

