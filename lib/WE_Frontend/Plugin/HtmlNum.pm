# -*- perl -*-

#
# $Id: HtmlNum.pm,v 1.3 2004/10/11 22:07:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::HtmlNum;
use base qw(Template::Plugin::Filter);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use HTML::Entities 1.27 (); # numeric entities

=head1 NAME

WE_Frontend::Plugin::HtmlNum - numeric html/xml entities

=head1 SYNOPSIS

    # In the calling script (normally already done by WebEditor::OldController)
    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    # In the template
    [% USE HtmlNum %]
    [% FILTER html_num %]
    ...
    [% END %]
    [% variable | html_num %]

=head1 DESCRIPTION

Like the html_entities filter, but use numeric entities instead.

=cut

sub init {
    my $self = shift;
    $self->install_filter("html_num");
    $self;
}

sub filter {
    my($self, $text) = @_;
    return HTML::Entities::encode_entities_numeric($text);
}

1;

__END__

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin::Filter>.

=cut

