package WebEditor::OldFeatures::MakeHTML;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub makehtmlpage_additional {
    my $self = shift;

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;

    my(%args) = @_;

    my $lang    = $args{lang}    || $c->project->sitelanguages->[0];
    my $basedir = $args{basedir} || $c->paths->pubhtmldir;

    my($id, $mainid, $template, $addtemplatevars) =
	@args{qw(id mainid template addtemplatevars)};

    my $htmlfile;
    # Die Homepage noch einmal als index.html erzeugen
    my $p = ($objdb->parents($mainid))[0];
    if ($p) {
	if ($p->is_site && defined $p->IndexDoc && $p->IndexDoc eq $mainid) {
	    $htmlfile = $basedir."/html/".$lang."/index.html";
	} elsif ($p->is_folder && defined $p->IndexDoc && $p->IndexDoc eq $mainid) {
	    $htmlfile = $basedir."/html/".$lang."/" . $p->Id . ".html";
	}
    }

    my $msg = "";

    my $converter = $self->get_fh_charset_converter;

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

    if (defined $htmlfile) {
	require File::Compare;
	my $tmpfile  = "$htmlfile~";
	open(HTML, ">$tmpfile") or $self->error("Publish: can't writeopen $tmpfile: $!");
	$converter->(\*HTML);
	$self->_tpl("site", $template, $addtemplatevars, \*HTML);
	close HTML;

	if (File::Compare::compare($htmlfile, $tmpfile) == 0) {
	    # no change --- delete $tmpfile
	    unlink $tmpfile;
	} else {
	    unlink $htmlfile; # do not fail --- maybe file does not exist
	    rename $tmpfile, $htmlfile or die "Can't rename $tmpfile to $htmlfile: $!";
	    $msg = " ($lang: $htmlfile) ";
	}

    }
    $msg;
}

1;
