#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 11_we_onlineuserdb.t,v 1.1.1.1 2002/08/06 18:34:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::DB::OnlineUser;

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
}

BEGIN { plan tests => 15 }

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

my $pwfile = "$testdir/test_onlineuser.db";
unlink $pwfile;

my $db = WE::DB::OnlineUser->new(undef, $pwfile, -timeout => 1);
ok($db->isa("WE::DB::OnlineUser"), 1);

$db->login("eserte");
ok($db->check_logged("eserte"), 1);
ok($db->check_logged("eserte",1000), 1);
my $result;
ok($db->check_logged("eserte",undef,\$result), 1);
ok($result =~ /^logged in/i, 1);
sleep 2;
ok($db->check_logged("eserte"), 0);
ok($db->check_logged("eserte",undef,\$result), 0);
ok($result =~ /timed out/i, 1);
ok($db->check_logged("eserte",1000), 1);
$db->ping("eserte");
ok($db->check_logged("eserte"), 1);
$db->logout("eserte");
ok($db->check_logged("eserte"), 0);
ok($db->check_logged("eserte",undef,\$result), 0);
ok($result =~ /^not logged in/i, 1);

__END__
