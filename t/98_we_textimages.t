#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 98_we_textimages.t,v 1.3 2003/01/19 14:31:09 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Config;

BEGIN {
    if (!eval q{
	use Test;
	use GD::Convert;
	use WE_Frontend::TextImages qw(text2gif);
	1;
    }) {
	print "# tests only work with installed Test and GD module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

my $ttf = "$FindBin::RealBin/misc/Generic.ttf";

my(%res) = text2gif(-f => $ttf, -text => 'Test');

ok($res{Image} =~ /GIF/, 1);

my $xv_pid;

if ($ENV{DISPLAY} && is_in_path("xv") && !$ENV{BATCH}) {
    if ($Config{'d_fork'} eq 'define') {
	pipe(RDR,WTR);
	if (fork == 0) {
	    close RDR;
	    $xv_pid = open(XV, "|-");
	    if ($xv_pid == 0) {
		exec("xv -");
		die "Can't open xv: $!";
	    }
	    print WTR $xv_pid, "\n";
	    close WTR;
	    print XV $res{Image};
	    close XV;
	    exit(0);
	}
	close WTR;
	chomp($xv_pid = <RDR>);
	close RDR;
    }
}

# XXX this is wrong with new GD/libgd --- why?
eval {
    my $dir = "/oo/onlineoffice/GmbH/Design/Coporate_Design/Fonts/HelveticaNeue/TrueType";
    if (!-d $dir) {
	die "$dir does not exist";
    }

    require Tk;
    require MIME::Base64;
    my $mw = MainWindow->new(-bg => "white");
#    $mw->optionAdd("*background", "white");

    foreach my $ttf (qw(HENUL___.TTF
			HENB____.TTF
			HENHI___.TTF
			HENH____.TTF
			HENI____.TTF
			HENLI___.TTF
			HENL____.TTF
			HENMI___.TTF
			HENM____.TTF
			HENR____.TTF
			HENTI___.TTF
			HENT____.TTF
			HENULI__.TTF
			HENBI___.TTF)) {

	my(%res) = text2gif(-bl => 1, -bt => 1, -br => 1, -bb => 1,
			    -f => "$dir/$ttf", -text => 'Test');

	my $p = $mw->Photo(-data => MIME::Base64::encode_base64($res{Image}));
	my $f = $mw->Frame->pack;
	$f->Label(-text => $ttf, -width => 20)->pack(-side => "left");
	$f->Label(-image => $p)->pack(-side => "left");
    }

    $mw->after(5000, sub { $mw->destroy });

    Tk::MainLoop();

    ok(1);
};
if ($@) {
    skip(1,1);
}

# The same as above, just find all .ttf files in the system and display them
eval {
    require File::Basename;
    my(@test_ttf) = split /\n/, `locate .ttf`;
    my @ttf;
    my %basettf;
    foreach my $ttf (@test_ttf) {
	my $base = File::Basename::basename($ttf);
	if (-r $ttf && $ttf =~ /\.ttf$/ && !exists $basettf{$base}) {
	    push @ttf, $ttf;
	    $basettf{$base}++;
	}
    }

    require Tk;
    require Tk::Pane;
    require MIME::Base64;
    my $mw0 = MainWindow->new(-bg => "white");
    my $mw = $mw0->Scrolled("Pane", -width => 350, -height => 500,
			    -scrollbars => "se")
	->pack(-fill => "both", -expand => 1);
#    $mw->optionAdd("*background", "white");

    foreach my $ttf (@ttf) {
	my(%res) = text2gif(-bl => 1, -bt => 1, -br => 1, -bb => 1,
			    -f => $ttf, -text => 'Test');

	my $p = $mw->Photo(-data => MIME::Base64::encode_base64($res{Image}));
	Tk::grid($mw->Label(-anchor => "w", -text => File::Basename::basename($ttf)),
		 $mw->Label(-image => $p),
		 -sticky => "w");
    }

    $mw0->after(5000, sub { $mw0->destroy });

    Tk::MainLoop();

    ok(1);
};
if ($@) {
    warn $@;
    skip(1,1);
}

kill 9 => $xv_pid if defined $xv_pid;

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

__END__
