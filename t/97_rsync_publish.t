#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_rsync_publish.t,v 1.1.1.1 2002/08/06 18:35:01 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests $pretests);

use FindBin;
use lib "$FindBin::RealBin/conf/new_publish_rsync"; # for WEsiteinfo.pm
use WE_Frontend::Main2;
use WEsiteinfo qw($c);

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    if (!$ENV{WE_FRAMEWORK_RSYNC_TEST}) {
	print "# Skipping rsync tests\n";
	print "# Please rerun with\n";
	print "#    env WE_FRAMEWORK_RSYNC_TEST=yes $^X -Mblib t/97_rsync_publish.t\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    $pretests = 1;
    $tests = 38;
}

BEGIN { plan tests => $tests }

use vars qw($fe $stagingdir);
$fe = new WE_Frontend::Main -config => $c;
ok($fe->isa('WE_Frontend::Main'), 1);

$stagingdir = $c->staging->directory;

my @dummy;
if (!eval '@dummy = getpwnam("dummy")') {
    warn "You need a dummy user with dummy password and
a ".$stagingdir." directory in his homedirectory.
";
    skip(1,1) for 1..$tests;
    exit;
}
if (!-d "$dummy[7]/.ssh") {
    warn "No .ssh directory for user dummy, probably no ssh configuration setup";
    skip(1,1) for 1..$tests;
    exit;
}

do "$FindBin::RealBin/publish_common.pl"; warn $@ if $@;

__END__
