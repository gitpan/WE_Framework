# -*- perl -*-

#
# $Id: TextTable.pm,v 1.10 2004/02/06 16:51:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::TextTable;
use base qw(Template::Plugin);

use HTML::Entities;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub fixeol ($);

=head1 NAME

WE_Frontend::Plugin::TextTable - format a textual table description to HTML

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE TextTable %]
    [% TextTable.out(tabledef) %]

=head1 DESCRIPTION

Format a textual table description into HTML. See also the "table"
definitions in F<we_contentlist_templates.tpl.js> in the web.editor
distribution.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context) = @_;
    my $self = {Context => $context};
    bless $self, $class;
}

=item out($tabledef)

Format and output the given table definition.

=cut

sub out {
    my($self, $tabledef) = @_;
    my $type  = $tabledef->{type};
    if ($type ne "table") {
	warn "Element type is `$type', expected `table'";
    }
    my $title           = fixeol $tabledef->{title};
    my $css             = fixeol $tabledef->{css};
    my $sep             = quotemeta fixeol $tabledef->{sep};
    my $head            = fixeol $tabledef->{tablehead};
    my $head_align      = fixeol $tabledef->{tablehead_align};
    my $head_is_html    = $tabledef->{tablehead_ishtml};
    my $subhead         = fixeol $tabledef->{tablesubhead};
    my $subhead_align   = fixeol $tabledef->{tablesubhead_align};
    my $subhead_is_html = $tabledef->{tablesubhead_ishtml};
    my $text_align      = fixeol $tabledef->{tabletext_align};
    my $text            = fixeol $tabledef->{tabletext};
    my @rows = split /\n/, $text;
    my $out = "<table";
    if (defined $css && $css ne "") {
	$out .= " class='$css'";
    }
    $out .= ">\n";
    if (defined $title && $title ne "") {
	$out .= "<caption>" . HTML::Entities::encode($title) . "</caption>\n";
    }
    for my $def ([$head,    $head_is_html,    $head_align],
		 [$subhead, $subhead_is_html, $subhead_align]
		) {
	my($h, $is_html, $align) = @$def;
	$align = "" if !defined $align;
	my @style = map {
	    my $style = parse_align($_);
	    if ($style ne "") {
		$style = " style='" . $style . "'";
	    }
	    $style;
	} split $sep, $align;

	if (defined $h && $h ne "") {
	    $out .= "<tr>";
	    if ($is_html) {
		$out .= $h;
	    } else {
		my @cols = split $sep, $h;
		my $col_i = 0;
		$out .= join "", map { my $s = defined $_ ? $_ : "";
				       my $style = $style[$col_i++] || "";
				       "<th$style>" . HTML::Entities::encode($s) . "</th>" } @cols;
	    }
	    $out .= "</tr>\n";
	}
    }

    $text_align = "" if !defined $text_align;
    my @td_style = map {
	my $style = parse_align($_);
	if ($style ne "") {
	    $style = " style='" . $style . "'";
	}
	$style;
    } split $sep, $text_align;

    for my $row (@rows) {
	$out .= "<tr>";
	my @cols = split $sep, $row;
	my $col_i = 0;
	$out .= join "", map { my $s = defined $_ ? $_ : "";
			       my $style = $td_style[$col_i++] || "";
			       "<td$style>" . HTML::Entities::encode($s) . "</td>" } @cols;
	$out .= "</tr>\n";
    }
    $out .= "</table>\n";

    return $out;
}

sub fixeol ($) {
    my $s = shift;
    return if !defined $s;
    $s =~ s/\015//g;
    $s;
}

sub parse_align {
    local $_ = shift;
    my $style = "";
    if (/[<l]/)  { $style .= ' text-align:left;'       }
    if (/[>r]/)  { $style .= ' text-align:right;'      }
    if (/[\|c]/) { $style .= ' text-align:center;'     }
    if (/[\^t]/) { $style .= ' vertical-align:top;'    }
    if (/[vb]/)  { $style .= ' vertical-align:bottom;' }
    if (/[-m]/)  { $style .= ' vertical-align:middle;' }
    $style;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>.

=cut

