#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 91_we_db_bench.t,v 1.5 2002/10/20 18:26:06 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($loop);

use FindBin;
use WE_Sample::Root;

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
    $loop = 200;
}

BEGIN { plan tests => $loop*2 }

BEGIN {
    # emulate system with low resources (e.g. Solaris 2)
    eval q{
	use BSD::Resource qw(setrlimit RLIMIT_OPEN_MAX);
	setrlimit(RLIMIT_OPEN_MAX, 64, 64);
    };
}

my $testdir = "$FindBin::RealBin/test";
for (1 .. $loop) {
    my $r = new WE_Sample::Root -rootdir => $testdir;
    ok(ref $r, 'WE_Sample::Root');
    $r->disconnect;
    ok(1);
}

__END__
