# -*- perl -*-

#
# $Id: Breadcrumb.pm,v 1.7 2004/01/12 16:33:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::Breadcrumb;
use base qw(Template::Plugin);

use HTML::Entities;

use WE::Util::LangString qw(langstring);
use WE_Frontend::Plugin::WE_Navigation;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::Breadcrumb - insert a "breadcrumb"

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE Breadcrumb %]
    [% Breadcrumb.out() %]

=head1 DESCRIPTION

Create a HTML breadcrumb.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context, $params) = @_;
    my $n = WE_Frontend::Plugin::WE_Navigation->new($context, $params);
    my $self = { WE_Navigation => $n };
    bless $self, $class;
}

=item out()

Format and output a breadcrumb for the current object id. The
following classes are used:

=over

=item breadcrumb

the overall breadcrumb (in a <span> element)

=item breadcrum_link

links in the breadcrumb

=back

The links are masked with <noindex> to help F<htdig>.

=cut

sub out {
    my($self) = @_;
    my $ancestors = $self->{WE_Navigation}->ancestors;
    # XXX classes ueberdenken
    '<span class="breadcrumb">' .
    join(" &gt; ", map {
	my $o = $_;
	my $url   = $o->relurl;
	my $title = $o->lang_title;
	'<a class="breadcrumb_link" href="' . $url . '"><noindex>' . HTML::Entities::encode($title) . "</noindex></a>";
    } @$ancestors) . '</span>';
}

1;

__END__

=back

=head1 TODO

=over

=item * Make the breadcrumb output customizable by using "mini-templates"

=item * show only parts of the breadcrumb list

=item * optimize the "doc-is-folderhead" case (by not showing the last
component of the breadcrumb in this case)

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>, L<htdig(1)>.

=cut

