#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 94_content_im_export.t,v 1.1 2003/08/17 19:57:28 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Env qw(@PATH);
use FindBin;
use Getopt::Long;
use File::Temp qw(tempdir);
use File::Basename qw(dirname basename);

BEGIN {
    if (!eval q{
	use Test;
	use File::NCopy qw(copy);
	1;
    }) {
	print "1..0 # skip: no Test and/or File::NCopy module\n";
	exit;
    }
}

push @PATH, "$FindBin::RealBin/../blib/script";

my @datadirs;
my $v;
my $cleanup = 1;
my @tempdirs;
my $ts = time;

$ENV{PERL_HASH_SEED} = 0; # make comparisons deterministic for 5.8.1 and above

GetOptions("datadir=s@" => \@datadirs,
	   "v" => \$v,
	   "cleanup!" => \$cleanup,
	  )
    or die "usage: $0 [-datadir ... ...] [-v] [-[no]cleanup]";

if (!@datadirs) {
    plan tests => 1;
    skip("No -datadir specified", 1);
    exit 0;
}

my @dumpformats = qw(YAML XML PerlDD);

plan tests => @datadirs * @dumpformats;

for my $dumpformat (@dumpformats) {
    for my $datadir (@datadirs) {
	eval {
	    my $destdir = tempdir
		(basename(dirname($datadir))."_".$dumpformat."_".$ts."_XXXXXX",
		 TMPDIR => 1, #CLEANUP => 1,
		);
	    push @tempdirs, $destdir;
	    my @cmd;
	    @cmd = ("env", "PERL5OPT=-Mblib=$FindBin::RealBin/..",
		    "we_export_content",
		    -dumpformat => $dumpformat,
		    -oldlang => "de", -newlang => "hr",
		    ($v ? "-v" : ()),
		    $datadir, $destdir,
		   );
	    warn "@cmd\n" if $v;
	    system @cmd and die "While executing @cmd";

	    my $wedatacopydir = tempdir
		(basename(dirname($datadir))."_1_".$ts."_XXXXXX",
		 TMPDIR => 1, #CLEANUP => 1,
		);
	    push @tempdirs, $wedatacopydir;

	    my $wedatacopydir2 = tempdir
		(basename(dirname($datadir))."_2_".$ts."_XXXXXX",
		 TMPDIR => 1, #CLEANUP => 1,
		);
	    push @tempdirs, $wedatacopydir2;

	    copy \1, "$datadir/*", $wedatacopydir;

	    @cmd = ("env", "PERL5OPT=-Mblib=$FindBin::RealBin/..",
		    "we_import_content",
		    ($v ? "-v" : ()),
		    $destdir, $wedatacopydir
		   );
	    warn "@cmd\n" if $v;
	    system @cmd and die "While executing @cmd";

	    copy \1, "$wedatacopydir/*", $wedatacopydir2;

	    @cmd = ("env", "PERL5OPT=-Mblib=$FindBin::RealBin/..",
		    "we_import_content",
		    ($v ? "-v" : ()),
		    $destdir, $wedatacopydir2
		   );
	    warn "@cmd\n" if $v;
	    system @cmd and die "While executing @cmd";

	    @cmd = ("diff", "-r",
		    "$wedatacopydir/content", "$wedatacopydir2/content");
	    warn "@cmd\n" if $v;
	    system @cmd and die "While executing @cmd";

	    if ($dumpformat eq 'XML' && is_in_path("xmllint")) {
		for my $f (glob("$destdir/*.xml")) {
		    @cmd = ("xmllint", "--noout", $f);
		    warn "@cmd\n" if $v;
		    system @cmd and die "While executing @cmd";
		}
	    }
	};
	if ($@) {
	    ok(0);
	    warn $@;
	} else {
	    ok(1);
	}
    }
}

END {
    # emulate cleanup
    system("rm -rf @tempdirs") if $cleanup;
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

__END__
