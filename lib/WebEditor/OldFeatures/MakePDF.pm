# -*- perl -*-

#
# $Id: MakePDF.pm,v 1.4 2004/03/08 10:43:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::MakePDF;

=head1 NAME

WebEditor::OldFeatures::MakePDF - create a PDF file from the site

=head1 SYNOPSIS

   use WebEditor::OldFeatures::MakePDF;
   WebEditor::OldFeatures::MakePDF::makepdf($webeditor_oldcontroller_object, %args);
   WebEditor::OldFeatures::MakePDF::makepdf_send($webeditor_oldcontroller_object, %args);

=head1 DESCRIPTION

This module uses the L<WebEditor::OldFeatures::MakePS> module in
conjunction with B<ps2pdf> from the B<ghostscript> distribution to
create PDF output from a web.editor site.

C<makepdf> and C<makepdf_send> pass all arguments to C<makeps> and
C<makeps_send>, respectively.

=head1 AUTHOR

Slaven Rezic

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use File::Temp qw(tempfile);

use WebEditor::OldFeatures::MakePS;

sub makepdf {
    my($self, %args) = @_;

    my $debug = $args{-debug};

    my($psfh,$pstmp) = tempfile(SUFFIX => ".ps",
				UNLINK => !$debug);
    my($pdffh,$pdftmp) = tempfile(SUFFIX => ".pdf",
				  UNLINK => !$debug);
    {
	local $args{-o} = $pstmp;
	WebEditor::OldFeatures::MakePS::makeps($self, %args);
    }

    my @cmd = ("ps2pdf");
    push @cmd, "-dCompatibilityLevel=1.2"; # or 1.3 or 1.4 ...
    push @cmd, "-dPDFSETTINGS=/printer";
    push @cmd, $pstmp, $pdftmp;

    warn "@cmd\n" if $debug;
    system(@cmd) and die "Error while doing @cmd";

    my $pdf;

    if (!defined $args{-o}) {
	open(FH, $pdftmp) or die "Can't open $pdftmp: $!";
	local $/ = undef;
	$pdf = <FH>;
	close FH;
	close $pdffh;
    }

    unless ($debug) {
	unlink $pstmp;
	unlink $pdftmp;
    }

    $pdf;
}

sub makepdf_send {
    my($self, %args) = @_;

    my $pdf = makepdf($self, %args);

    my $q = CGI->new;
    print $q->header("application/pdf");
    print $pdf;
    return 1;
}

1;
