#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 91_namedb.t,v 1.3 2002/12/10 00:08:10 eserte Exp $
# Author: Slaven Rezic
#

use strict;
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
}

BEGIN { plan tests => 29*3 }

my @test_names = (qw(sequence-test named_object), 'test for 93_navigation_plugin');

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

if ($Test::VERSION <= 1.122) {
    $^W = 0; # too many warnings
}

my $first_pass = 1;
for my $connect (undef, 0, 1) {
    print "# connect type is " . (!defined $connect ? "undefined" : $connect) . "\n";
    my $r2 = new WE::DB -class => 'WE_Sample::Root',
                        -rootdir => $testdir,
		        -connect => $connect;
    ok(ref $r2, 'WE_Sample::Root');
    $r2->ObjDB(undef); # to prevent deadlocks --- but a simple "undef $r2" should be enough!!! XXX
    ok($r2->ObjDB, undef);
    undef $r2; # XXX

    my $r = new WE_Sample::Root -rootdir => $testdir,
                                -connect => $connect;
    ok(ref $r, 'WE_Sample::Root');
    ok($r->RootDir, $testdir);

    $r->init;

    ok(-e "$testdir/name.db");

    my $objdb = $r->ObjDB;
    my $namedb = $r->NameDB;
    ok(UNIVERSAL::isa($namedb, "WE::DB::Name"));

    # pre rebuild_db_contents test (should be built by the 90_sample.t test)
    if ($first_pass) {
	for my $name (@test_names) {
	    my $id = $namedb->get_id($name);
	    ok(defined $id, 1, "check for $name");
	    my $o = $objdb->get_object($id);
	    ok(defined $o, 1, "check for $name");
	    ok($o->{Name}, $name, "check for $name");
	}

	ok($namedb->get_id("will_be_removed"), undef);
    }

    # performance
    if (eval 'require Time::HiRes') {
	my $count = (defined $connect && $connect == 0 ? 20 : 100);
	{
	    my $t0 = [Time::HiRes::gettimeofday()];
	    for my $i (1..$count) {
		for my $name (@test_names) {
		    my $id = $namedb->get_id($name);
		    my $o = $objdb->get_object($id);
		}
	    }
	    my $elapsed = Time::HiRes::tv_interval($t0);
	    if ($elapsed) {
		printf "# %.3fms per get object by name\n", 1000*($elapsed/($count*@test_names));
	    }
	}

	{
	    my $t0 = [Time::HiRes::gettimeofday()];
	    for my $i (1..$count) {
		for my $name (@test_names) {
		    my $id = $objdb->name_to_objid($name);
		    my $o = $objdb->get_object($id);
		}
	    }
	    my $elapsed = Time::HiRes::tv_interval($t0);
	    if ($elapsed) {
		printf "# %.3fms per get object by name (name_to_objid)\n", 1000*($elapsed/($count*@test_names));
	    }
	}
    }

    $namedb->delete_db_contents;
    ok(scalar keys %{$namedb->{DB}}, 0);

    $namedb->rebuild_db_contents;

    for my $name (@test_names) {
	my $id = $namedb->get_id($name);
	ok(defined $id, 1, "check for $name");
	my $o = $objdb->get_object($id);
	ok(defined $o, 1, "check for $name");
	ok($o->{Name}, $name, "check for $name");
    }

    # positive existance
    for my $name (@test_names) {
	ok($namedb->exists($name));
    }
    # negative existance
    ok(!$namedb->exists("this_name_does_not_exist!!!"));

    for my $name (@test_names) {
	ok(($namedb->get_names($namedb->get_id($name)))[0], $name);
    }

    # all names
    my @all_names = $namedb->all_names;
    ok(grep { $_ eq $test_names[0] } @all_names);
    ok(grep { $_ eq $test_names[-1] } @all_names);

    $first_pass = 0;

    $r->disconnect; # to prevent deadlocks...
}

__END__
