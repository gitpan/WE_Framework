#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_mainany_new.t,v 1.1.1.1 2002/08/06 18:35:01 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests);

use WE_Frontend::MainAny;

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

    $tests = 2;
}

BEGIN { plan tests => $tests }

my $olddir = "$ENV{HOME}/public_html/webeditor/wwwroot";
if (-r "$olddir/cgi-bin/WEsiteinfo.pm") {
    push @INC, "$olddir/cgi-bin";

    my $main = WE_Frontend::MainAny->new(undef);
    ok($main->isa("WE_Frontend::Main"), 1);
    ok($main->Config->paths->rootdir, $olddir);
} else {
    skip(1,1) for (1..$tests);
}

__END__
