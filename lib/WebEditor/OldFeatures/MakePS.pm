# -*- perl -*-

#
# $Id: MakePS.pm,v 1.8 2004/03/08 10:43:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::MakePS;

=head1 NAME

WebEditor::OldFeatures::MakePS - create a postscript file from the site

=head1 SYNOPSIS

   use WebEditor::OldFeatures::MakePS;
   WebEditor::OldFeatures::MakePS::makeps($webeditor_oldcontroller_object, %args);
   WebEditor::OldFeatures::MakePS::makeps_send($webeditor_oldcontroller_object, %args);

=head1 DESCRIPTION

This module provides the B<makeps> function which create Postscript
output from a web.editor site. It uses html2ps (available from
L<http://user.it.uu.se/~jan/html2ps.html>) to create the output from
an intermediate auto-generated HTML page (which is generated by
L<WebEditor::OldFeatures::MakeOnePageHTML>).

See L<WebEditor::OldFeatures::MakeOnePageHTML> for a description on
HTML templates.

=head2 FUNCTIONS

The B<makeps> function arguments:

=over

=item -o => $output_file

Specify an output file. If not set, then the output will be returned
by the B<makeps> function.

=item -toc => $bool

Create a TOC at the end of the document.

=item -pagenumbers => $bool

Use page numbers. Turned by default on if C<-toc> is set.

=back

The function also accepts C<-lang> and C<-debug> like
B<makeonepagehtml>.

The B<makeps_send> function arguments are same as for B<makeps>. This
function automatically creates an HTTP header and prints the output to
STDOUT.

=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use CGI ();
use File::Temp qw(tempfile);

use WE_Frontend::Plugin::Linear;
use WE::Util::LangString qw(langstring);
use WebEditor::OldFeatures::MakeOnePageHTML;

sub makeps {
    my($self, %args) = @_;

    my $debug = $args{-debug};

#     my $objdb = $self->Root->ObjDB;
#     my $root_object = $objdb->root_object;
#     my $c = $self->C;

#     my @objids;
#     my $curr_id = $root_object->Id;

#     while (1) {
# 	my $doc_id = $curr_id;
# 	# XXX code doubled in WE_Frontend::Plugin::WE_Navigation::Object
# 	# XXX IndexDoc handling missing!
# 	my $obj = $objdb->get_object($curr_id);
# 	if ($obj->is_folder) {
# 	    if (defined $obj->IndexDoc) {
# 		$doc_id = $obj->IndexDoc;
# 	    } else {
# 		my $autoindexdoc = $c->project->features->{autoindexdoc};
# 		if (defined $autoindexdoc && $autoindexdoc eq 'first') {
# 		    my(@children_ids) = $objdb->get_released_children($curr_id);
# 		    if (@children_ids) {
# 			$doc_id = $children_ids[0]->Id;
# 		    } else {
# 			undef $doc_id;
# 		    }
# 		}
# 	    }
# 	}
# 	push @objids, {Id => $curr_id, DocId => $doc_id};

# 	if (defined $doc_id) {
# 	    # XXX document WE_Frontend::Plugin::Linear how to use in
# 	    # offline (non-TT) mode
# 	    my $linear = WE_Frontend::Plugin::Linear->new
# 		(undef,
# 		 { rootdb => $self->Root,
# 		   objdb  => $objdb,
# 		   objid  => $doc_id,
# 		 },
# 		);
# 	    my $next = $linear->next;
# 	    if (defined $next) {
# 		$curr_id = $next->o->Id;
# 	    } else {
# 		last;
# 	    }
# 	} else {
# 	    die "XXX Non-linear site (folder object $curr_id has no indexdoc)";
# 	}
#     }

#     my $lang  = $args{-lang} || $c->project->sitelanguages->[0] || "en";
#     my $debug = $args{-debug};

#     my $html_ps = "";
#     my $t = Template->new($self->TemplateConf);

#     # XXX OK to hardcode template name?
#     $t->process
# 	($c->paths->site_templatebase . "/html_ps_header.tpl.html",
# 	 { %{ $self->TemplateVars },
# 	   lang => $lang,
# 	 }, \$html_ps) or die $t->error;

#     for my $def (@objids) {
# 	my $id = $def->{Id};
# 	my $doc_id = $def->{DocId};

# 	# XXX code doubled from makehtmlpage...
# 	my $content = $objdb->content($doc_id);
# 	my $outdata = $self->_get_outdata($content);
# 	my $obj = $objdb->get_object($doc_id);
# 	my $mainid = $obj->Version_Parent || $doc_id;
# 	my $template = $c->project->templatefortype->{ $outdata->{'data'}->{'pagetype'} };
# 	if (!defined $template) {
# 	    die "No template for pagetype $outdata->{'data'}->{'pagetype'} defined";
# 	}

# 	my $folder_title;
# 	my $folder_done;
# 	if ($id != $doc_id) {
# 	    my $folder_obj = $objdb->get_object($id);
# 	    $folder_title = langstring($folder_obj->Title, $lang);
# 	    my $template_file = $c->paths->site_templatebase . "/html_ps_headline.tpl.html";
# 	    $html_ps .= "<!-- Folder id $id, title " . HTML::Entities::encode($folder_title) . ", template file $template_file -->\n";
# 	    $t->process
# 		($template_file,
# 		 { %{ $self->TemplateVars },
# 		   lang => $lang,
# 		   objid => $id,
# 		   object => $folder_obj,
# 		   title => $folder_title,
# 		   level => ($objdb->depth($folder_obj))[0],
# 		   pagetype => "_folder",
# 		 }, \$html_ps) or die $t->error;
# 	    $folder_done = 1;
# 	}

# 	my $page_title = langstring($obj->Title, $lang);
# 	$html_ps .= "<!-- Page id $id, title " . HTML::Entities::encode($page_title) . " -->\n";

# 	$outdata->{'data'}->{'language'} = $lang;
# 	my $keywords = langstring($obj->{Keywords}, $lang) || undef;
# 	#warn "Using template ".$c->paths->site_templatebase."/".$template."\n";
# 	$template =~ s/\.tpl\.html$/_ps\.tpl\.html/;

# 	$t->process($c->paths->site_templatebase."/".$template,
# 		    { %{ $self->TemplateVars },
# 		      objid => $mainid,
# 		      lang => $lang,
# 		      keywords => $keywords,
# 		      level => ($objdb->depth($mainid))[0],
# 		      omit_title => (defined $page_title && $page_title eq $folder_title),
# 		      omit_pagebreak => $folder_done,
# 		      %$outdata },
# 		    \$html_ps)
# 	    or die "Template process failed: " . $t->error . "\n";
#     }

#     # XXX OK to hardcode template name?
#     $html_ps .= "<!-- footer -->\n";
#     $t->process
# 	($c->paths->site_templatebase . "/html_ps_footer.tpl.html",
# 	 { %{ $self->TemplateVars },
# 	   lang => $lang,
# 	 },
# 	\$html_ps)
# 	    or die $t->error;

    my($htmlfh,$htmltmp) = tempfile(SUFFIX => ".html",
				    UNLINK => !$debug);
    {
	local $args{-o} = $htmltmp;
	WebEditor::OldFeatures::MakeOnePageHTML::makeonepagehtml($self, %args);
    }

    my($psfh, $pstmp);
    if (!defined $args{-o}) {
	($psfh, $pstmp) = tempfile(SUFFIX => ".ps",
				   UNLINK => !$debug);
    }

    my @cmd = ('html2ps');
    push @cmd, '-D';
    if ($args{-toc}) {
	push @cmd, "-C", "h";
    }
    if ($debug) {
	# XXX writes to current directory, which might be unwritable
	#push @cmd, "-d";
    }
    if ($args{-pagenumbers}) {
	push @cmd, "-n";
    }
    if ($args{-o}) {
	push @cmd, "-o", $args{-o};
    } else {
	push @cmd, "-o", $pstmp;
    }
    push @cmd, $htmltmp;

    warn "@cmd\n" if $debug;
    system(@cmd) and die "Error while doing @cmd";

    my $ps;

    if (!defined $args{-o}) {
	open(FH, $pstmp) or die "Can't open $pstmp: $!";
	local $/ = undef;
	$ps = <FH>;
	close FH;
	close $psfh;
    }

    unless ($debug) {
	unlink $htmltmp;
	unlink $pstmp;
    }

    $ps;
}

sub makeps_send {
    my($self, %args) = @_;

    my $ps = makeps($self, %args);

    my $q = CGI->new;
    print $q->header("application/postscript");
    print $ps;
    return 1;
}

1;