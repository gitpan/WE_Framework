# -*- perl -*-

#
# $Id: PrintTemplates.pm,v 1.1 2005/01/29 16:48:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sourceforge.net/projects/we-framework
#

package WebEditor::OldFeatures::PrintTemplates;

=head1 NAME

WebEditor::OldFeatures::PrintTemplates - additionally process print templates

=head1 SYNOPSIS

=head1 DESCRIPTION

Add the method makehtmlpage_print_templates to
L<WebEditor::OldController>. This method is normally accessed as the
C<print_templates> hook in the C<makehtmlhook> feature, see
L<configuration.pod>.

=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

# add mixin'ed methods here

sub makehtmlpage_print_templates {
    my $self = shift;

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;

    my(%args) = @_;

    my $lang    = $args{lang}    || $c->project->sitelanguages->[0];
    my $basedir = $args{basedir} || $c->paths->pubhtmldir;

    my($id, $mainid, $template, $addtemplatevars) =
	@args{qw(id mainid template addtemplatevars)};

    my $msg = "";

    # gibt es von diesem Template noch ein Print-Template?
    # dann nochmal die Print-Version erzeugen:
    my $printtemplate = $template;
    $printtemplate =~ s/\.tpl\.html$/_p\.tpl\.html/;
    if (-e $c->paths->site_templatebase."/$printtemplate") {
	$msg .= "$printtemplate --- ";
	require File::Compare;
	my $phtmlfile = $basedir."/html/".$lang."/".$mainid."_p.html";
	$msg .= "$phtmlfile --- ";
	my $tmpfile = "$phtmlfile~";

	my $converter = $self->get_fh_charset_converter;

	open(HTML, ">$tmpfile") or die("Publish: can't write to $tmpfile: $!");
	$converter->(\*HTML);
	$self->_tpl("site", $printtemplate, $addtemplatevars, \*HTML);
	close HTML;

	if (File::Compare::compare($phtmlfile, $tmpfile) == 0) {
	    # no change --- delete $tmpfile
	    unlink $tmpfile;
	    $msg .= " ($lang: keine Änderung) ";
	} else {
	    unlink $phtmlfile; # do not fail --- maybe file does not exist
	    rename $tmpfile, $phtmlfile or die "Can't rename $tmpfile to $phtmlfile: $!";
	}

    }

    return { Message => $msg };
}

1;
