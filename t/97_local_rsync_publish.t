#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_local_rsync_publish.t,v 1.4 2007/10/04 19:17:57 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests $pretests);

use FindBin;
use lib "$FindBin::RealBin/conf/new_publish_local_rsync"; # for WEsiteinfo.pm
use WE_Frontend::Main2;
use WEsiteinfo qw($c);

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/work/srezic-repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

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
# REPO NAME file_name_is_absolute /home/e/eserte/work/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

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

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip: tests only work with installed Test module\n";
	exit;
    }

    if (!is_in_path("rsync")) {
	print "1..1\n";
	print "ok 1 # skip: test only work with rsync available\n";
	exit;
    }

    $pretests = 1;
    $tests = 38;
}

BEGIN { plan tests => $pretests+$tests }

use vars qw($fe $stagingdir $stagingcgidir $testname);
$fe = new WE_Frontend::Main -config => $c;
ok($fe->isa('WE_Frontend::Main'), 1);

$stagingdir = $c->staging->directory;
$stagingcgidir = $c->staging->cgidirectory;

mkdir $stagingdir, 0755    if !-d $stagingdir;
mkdir $stagingcgidir, 0755 if !-d $stagingcgidir;

if (!-w $stagingdir) {
    skip("$stagingdir is not writable for you",1) for 1..$tests;
    exit;
}

$testname = "local_rsync_publish";

do "$FindBin::RealBin/publish_common.pl"; warn $@ if $@;

if ($stagingdir eq "/tmp/testproject_live-$<") {
    system("rm -rf $stagingdir");
} else {
    warn "Do not cleanup $stagingdir!!! Please check!";
}

__END__
