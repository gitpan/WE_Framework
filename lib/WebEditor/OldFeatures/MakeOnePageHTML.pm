# -*- perl -*-

#
# $Id: MakeOnePageHTML.pm,v 1.3 2004/12/22 11:23:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::MakeOnePageHTML;

=head1 NAME

WebEditor::OldFeatures::MakeOnePageHTML - create a postscript file from the site

=head1 SYNOPSIS

   use WebEditor::OldFeatures::MakeOnePageHTML;
   WebEditor::OldFeatures::MakeOnePageHTML::makeonepagehtml($webeditor_oldcontroller_object, %args);
   WebEditor::OldFeatures::MakeOnePageHTML::makeonepagehtml_send($webeditor_oldcontroller_object, %args);

=head1 DESCRIPTION

This module provides the B<makeonepagehtml> function which creates a
single page HTML a web.editor site.

=head2 HTML TEMPLATES

The HTML templates should be the same as the normal pagetype templates
with the suffix C<_oph.tpl.html> instead of C<.tpl.html>. Usually these
templates contain only partial HTML without C<< <html> >>, C<< <head>
>> and C<< <body> >> tags and should have no navigational elements.

The templates receive the normal parameters as in B<makehtmlpage> and
additionally the parameters C<level> (useful in constructing the C<<
<h...> >> tag) and C<omit_title> (true if it is advisable to omit the
C<< <h...> >> tag).

Additionally, the following templates should be defined:

=over

=item one_page_html_header.tpl.html

The overall header of the HTML document. Here goes the C<< <head> >>
definitions and the opening C<< <html> >> and C<< <body> >> tags.

The template receives the normal TemplateVars and additionally the
current C<lang> parameter.

=item one_page_html_footer.tpl.html

The overall footer of the HTML document. Here goes the closing C<<
<html> >> and C<< <body> >> tags along with footer text for the
document.

The template receives the normal TemplateVars and additionally the
current C<lang> parameter.

=item one_page_html_headline.tpl.html

A template for a folder object with no own content. Typically this
will contain only one C<< <h...>title</h...> >> element.

This template receives the normal TemplateVars and additionally the
C<lang>, C<object> (the current L<WE::Obj> object), C<title> and
C<level>.

=back

=head2 FUNCTIONS

The B<makeonepagehtml> function arguments:

=over

=item -lang => $lang

The language to process. By default the first site language is used.

=item -debug => $bool

Turn on debug mode if true. This will leave the temporary files after
processing and show the command line arguments.

=item -o => $output_file

Specify an output file. If not set, then the output will be returned
by the B<makeonepagehtml> function.

=back

The B<makeonepagehtml_send> function arguments are same as for
B<makeonepagehtml>. This function automatically creates an HTTP header
and prints the output to STDOUT.

=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use CGI ();
use HTML::Entities ();
use Template;

use WE_Frontend::Plugin::Linear;
use WE::Util::LangString qw(langstring);

sub makeonepagehtml {
    my($self, %args) = @_;

    my $objdb = $self->Root->ObjDB;
    my $root_object = $objdb->root_object;
    my $c = $self->C;

    my @objids;
    my $curr_id = $root_object->Id;

    while (1) {
	my $doc_id = $curr_id;
	# XXX code doubled in WE_Frontend::Plugin::WE_Navigation::Object
	# XXX IndexDoc handling missing!
	my $curr_obj = $objdb->get_object($curr_id);
	if ($curr_obj->is_folder) {
	    if (defined $curr_obj->IndexDoc) {
		$doc_id = $curr_obj->IndexDoc;
	    } else {
		my $autoindexdoc = $c->project->features->{autoindexdoc};
		if (defined $autoindexdoc && $autoindexdoc eq 'first') {
		    my(@children_ids) = $objdb->get_released_children($curr_id);
		    if (@children_ids) {
			$doc_id = $children_ids[0]->Id;
		    } else {
			undef $doc_id;
		    }
		}
	    }
	}
	push @objids, {Id => $curr_id, DocId => $doc_id};

	if (defined $doc_id) {
	    # XXX document WE_Frontend::Plugin::Linear how to use in
	    # offline (non-TT) mode
	    my $linear = WE_Frontend::Plugin::Linear->new
		(undef,
		 { rootdb => $self->Root,
		   objdb  => $objdb,
		   objid  => $doc_id,
		 },
		);
	    my $next = $linear->next;
	    if (defined $next) {
		$curr_id = $next->o->Id;
	    } else {
		last;
	    }
	} else {
	    die "This is a non-linear site. The folder object <" . langstring($curr_obj->Title) . "> (Id $curr_id) has no Index document.";
	}
    }

    my $lang  = $args{-lang} || $c->project->sitelanguages->[0] || "en";
    my $debug = $args{-debug};

    my $html = "";
    my $t = Template->new($self->TemplateConf);

    # XXX OK to hardcode template name?
    $t->process
	($c->paths->site_templatebase . "/one_page_html_header.tpl.html",
	 { %{ $self->TemplateVars },
	   lang => $lang,
	 }, \$html) or die $t->error;

    for my $def (@objids) {
	my $id = $def->{Id};
	my $doc_id = $def->{DocId};

	# XXX code doubled from makehtmlpage...
	my $content = $objdb->content($doc_id);
	my $outdata = $self->_get_outdata($content);
	my $obj = $objdb->get_object($doc_id);
	my $mainid = $obj->Version_Parent || $doc_id;
	my $template = $c->project->templatefortype->{ $outdata->{'data'}->{'pagetype'} };
	if (!defined $template) {
	    die "No template for pagetype $outdata->{'data'}->{'pagetype'} defined";
	}

	my $folder_title;
	my $folder_done;
	if ($id != $doc_id) {
	    my $folder_obj = $objdb->get_object($id);
	    $folder_title = langstring($folder_obj->Title, $lang);
	    my $template_file = $c->paths->site_templatebase . "/one_page_html_headline.tpl.html";
	    $html .= "<!-- Folder id $id, title " . HTML::Entities::encode($folder_title) . ", template file $template_file -->\n";
	    $t->process
		($template_file,
		 { %{ $self->TemplateVars },
		   lang => $lang,
		   objid => $id,
		   object => $folder_obj,
		   title => $folder_title,
		   level => ($objdb->depth($folder_obj))[0],
		   pagetype => "_folder",
		 }, \$html) or die $t->error;
	    $folder_done = 1;
	}

	my $page_title = langstring($obj->Title, $lang);
	$html .= "<!-- Page id $id, title " . HTML::Entities::encode($page_title) . " -->\n";

	$outdata->{'data'}->{'language'} = $lang;
	my $keywords = langstring($obj->{Keywords}, $lang) || undef;
	#warn "Using template ".$c->paths->site_templatebase."/".$template."\n";
	$template =~ s/\.tpl\.html$/_oph\.tpl\.html/;

	$t->process($c->paths->site_templatebase."/".$template,
		    { %{ $self->TemplateVars },
		      objid => $mainid,
		      lang => $lang,
		      keywords => $keywords,
		      level => ($objdb->depth($mainid))[0],
		      omit_title => (defined $page_title && $page_title eq $folder_title),
		      omit_pagebreak => $folder_done,
		      %$outdata },
		    \$html)
	    or die "Template process failed: " . $t->error . "\n";
    }

    # XXX OK to hardcode template name?
    $html .= "<!-- footer -->\n";
    $t->process
	($c->paths->site_templatebase . "/one_page_html_footer.tpl.html",
	 { %{ $self->TemplateVars },
	   lang => $lang,
	 },
	\$html)
	    or die $t->error;

    if (defined $args{-o}) {
	open(HTML, ">$args{-o}") or die "Can't write to $args{-o}: $!";
	print HTML $html;
	close HTML;
    } else {
	return $html;
    }
}

sub makeonepagehtml_send {
    my($self, %args) = @_;

    my $html = makeonepagehtml($self, %args);

    my $q = CGI->new;
    print $q->header("text/html");
    print $html;
    return 1;
}

1;
