#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 91_hw.t,v 1.1.1.1 2002/08/06 18:34:59 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test;
	use WE_Sample::HW;
	1;
    }) {
	print "# tests only work with installed Test and HyperWave::CSP modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN {
    if ($ENV{USER} ne 'eserte') {
	plan tests => 1;
	ok(1);
	exit;
    }
}

BEGIN { plan tests => 6, todo => [5..6] }

# XXX bug: one cannot specify another host other than the local one !?
my $r;
my $id_res = 0;
eval {
    $r = new WE_Sample::HW "mom", undef, -rootcollection => "srt";
    $id_res = $r->identify("hwsyst55", "hwsystem");
};
if ($@ || !$r || !$id_res) {
    skip("Cannot connect to Hyperwave server",1) for (1..6);
    exit;
}
ok($id_res, 1);
my $objdb = $r->ObjDB;
ok($objdb->isa("WE::DB::HWObj"), 1);

my $root_obj = $objdb->root_object;
ok($root_obj->isa("WE::Obj::Site"), 1);

my $any_obj = $objdb->get_object(13474);
ok($any_obj->isa("WE::Obj"), 1);
my $content;
$content = $objdb->content($any_obj) if $any_obj;
ok(length $content > 0, 1);

if ($^O eq 'MSWin32') {
    skip(1,1);
} elsif (!eval 'require IPC::Open2; 1') {
    skip(1,1);
} else {
    my $pid = IPC::Open2::open2(\*RDRFH, \*WTRFH, 'file', '-');
    if (defined $content) {
	print WTRFH $content;
	ok(<RDRFH> =~ /gif/i, 1);
    } else {
	ok(0);
    }
}

# XXX it's slow for large servers!
#print $objdb->dump;

__END__
