#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_local_rsync_publish.t,v 1.3 2004/12/21 23:19:26 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests $pretests);

use FindBin;
use lib "$FindBin::RealBin/conf/new_publish_local_rsync"; # for WEsiteinfo.pm
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
