#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 95_soap.t,v 1.1.1.1 2002/08/06 18:35:00 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use WE::Obj;
use WE::Util::LangString qw(langstring);

BEGIN {
    if (!eval q{
	use Test;
	use SOAP::Lite;
	1;
    }) {
	print "# tests only work with installed Test and SOAP::Lite modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

#BEGIN { plan tests => 9 }
BEGIN { plan tests => 1 }#XXX

ok(1);
exit(0);#XXX this test tests nothing anymore!

WE::Obj->use_classes(qw/:all/);

# XXX start server automatically!
my $port = shift||8123;
my $proxy = "http://localhost:$port/";
my $uri   = "WE_Sample/Root";
my $uri2  = "WE/DB/Obj";

my $soap = SOAP::Lite->proxy($proxy);
$soap->uri($uri) if $uri;
ok(defined $soap, 1);

my $soap2 = SOAP::Lite->proxy($proxy);
$soap2->uri($uri2) if $uri2;
ok(defined $soap2, 1);

my $rootdb = $soap->call('new',
			 -rootdir => "$FindBin::RealBin/test",
			 -readonly => 1,
			 -locking => 0)->result;
ok(ref $rootdb, 'WE_Sample::Root');

ok($soap->call('login' => $rootdb,
	       "motu", "utom")->result, 1);

my $objdb = $soap->call('ObjDB' => $rootdb)->result;
ok(ref $objdb, 'WE::DB::Obj');

my $root_obj = $soap2->call('root_object' => $objdb)->result;
ok($root_obj->is_folder, 1);
ok($root_obj->{Id}, 0);
ok(langstring($root_obj->{Title}), "Root of the site");

__END__
