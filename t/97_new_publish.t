#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_new_publish.t,v 1.2 2003/08/17 19:57:28 eserte Exp $
# Author: Slaven Rezic
#

# XXX This test should be rewritten.

use strict;
use vars qw($tests $pretests);

use FindBin;
use lib "$FindBin::RealBin/conf/new_publish_ftp"; # for WEsiteinfo.pm
use WE_Frontend::Main2;
use WEsiteinfo qw($c);

BEGIN {
    if (!eval q{
	use Test;
	use Net::Domain qw(hostdomain);
	die "Not here" if hostdomain ne "intra.onlineoffice.de";
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

use vars qw($fe $stagingdir);
$fe = new WE_Frontend::Main -config => $c;
ok($fe->isa('WE_Frontend::Main'), 1);

$stagingdir = $c->staging->directory;

do "$FindBin::RealBin/publish_common.pl"; warn $@ if $@;

__END__