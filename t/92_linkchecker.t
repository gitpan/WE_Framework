#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 92_linkchecker.t,v 1.3 2004/02/03 18:37:14 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Sys::Hostname;
use FindBin;

BEGIN {
    if (!eval q{
	use Test;
	use Template;
	use HTML::LinkExtor
	die if !$ENV{LINKCHECKER_TEST} && hostname ne "vran.herceg.de";
	1;
    }) {
	print "# tests only work with installed Test, Template and HTML::LinkExtor modules and\n";
	print "# the environment variable LINKCHECKER_TEST set to a true value\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

use WE_Frontend::LinkChecker;

BEGIN { plan tests => 2 }

#$WE_Frontend::LinkChecker::VERBOSE = 1;
my $lc = WE_Frontend::LinkChecker->new
    (-url => "http://www/~eserte/met/",
     -restrict => ['^http://(?:www|vran)(?:\.herceg\.de)?/~eserte/met/'],
    );
my $html = $lc->check_html;
ok($html ne "");
#warn $html;
my $html2 = $lc->check_tt
    (Template->new(INCLUDE_PATH => "$FindBin::RealBin/testtt",
		   DEBUG => 0,
		  ),
     "we_linkchecker_result.tpl.html",
     {config => { paths => { we_htmlurl => "htmlurl",
			     cgiurl => "cgiurl",
			     scheme => "http",
			     servername => "server",
			   } } });
ok($html2, qr/Ergebnisse der Linküberprüfung/);
#warn $html2;

__END__
