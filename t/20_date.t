#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 20_date.t,v 1.3 2003/01/16 14:29:11 eserte Exp $
# Author: 
#
# Copyright (C) 2000 Onlineoffice. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  we-framework.sourceforge.net
#

use strict;

BEGIN {
    if (!eval q{
	use Test;
	use Template;
	die "Wrong timezone" if scalar localtime !~ /\bCES?T\b/;
	1;
    }) {
	print "# tests only work with installed Test in the CET timezone\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 7 }

use WE::Util::Date;

warn "This test will only work in MET timezone!\n";

ok(WE::Util::Date::isodate2epoch("1970-01-01 00:00:00"), -3600);
ok(isodate2epoch("1970-01-01 00:00:00"), -3600);
ok(isodate2epoch("1970-01-01"), -3600);

ok(epoch2isodate(0), "1970-01-01 01:00:00");

# negative numbers to localtime/gmtime does not work with ActivePerl
ok(WE::Util::Date::short_readable_time(0), "Jan  1  1970");

# summertime check
ok(WE::Util::Date::isodate2epoch("2002-08-06 00:00:00"), 1028584800);
ok(isodate2epoch("2002-08-06 00:00:00"), 1028584800);

__END__
