#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 92_concurrent.t,v 1.4 2002/10/20 18:26:06 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE_Sample::Root;
use WE::Util::Support;

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

BEGIN { plan tests => 10 }

my $testdir = "$FindBin::RealBin/test2";
ok(-d $testdir, 1);
ok(-w $testdir, 1);

pipe(RDR,WTR);
my $pid = fork;
if (!defined $pid) {
    die "fork failed";
}
if ($pid == 0) {
    close WTR;
    child();
    exit 0;
}
close RDR;

my $r = new WE::DB -class => 'WE_Sample::Root',
                   -rootdir => $testdir,
                   -locking => 1,
                   -connect => 1;
print WTR "connected to database\n";

ok(ref $r, 'WE_Sample::Root');
my $objdb = $r->ObjDB;
ok(grep { $_ eq 'write' } @{$objdb->DBTieArgs});

ok(ref $objdb, 'WE::DB::Obj');
$r->delete_db_contents;

{
    my $integrity_check = $objdb->check_integrity;
    ok($integrity_check->has_errors, 0, "Integrity check");
    if ($integrity_check->has_errors) {
	require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	    Data::Dumper->new([$integrity_check],[])->Indent(1)->Useqq(1)->Dump;
    }
}

{
    my $integrity_check2 = $r->ContentDB->check_integrity($objdb);
    ok($integrity_check2->has_errors, 0, "Integrity check for ContentDB");
    if ($integrity_check2->has_errors) {
	require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	    Data::Dumper->new([$integrity_check2],[])->Indent(1)->Useqq(1)->Dump;
    }
}

$objdb->create_folder_tree(-standardargs => {-Rights => 'All rights'},
			   -string => <<'EOF');
-Title "Support 1" -Rights "No rights" -Name norights
 -Title "Support 1/1"
  -Title "Support 1/1/1"
 -Title "Support 1/2"
-Title "Support 2" -Name support2_name
 -Title "Support 2/1" -Name support21_name
  -Title "Support 2/1/1" -Name support211_name
   -Title "Support 2/1/1/1" -Name support2111_name
  -Title "Support 2/1/2"
   -Title "Support 2/1/2/1" -Release_State norel
   -Title "Support 2/1/2/2" -Name support2122_name
 -Title "Support 2/2"
  -Title "Support 2/2/1"
 -Title "en:Support english 2/3" "de:Support german 2/3"
 -Title "xxx:Support 2/4 no lang"
 -Title "de:Support german 2/5" "en:Support english 2/5" -Name anothername
 -Title "Support 2/6"
EOF

# why is this necessary?
$objdb->disconnect;
$r->NameDB->disconnect;
print WTR "disconnected from database\n";
close WTR;

my $support2_name_id = $objdb->name_to_objid("support2_name");

for(1..100) {
    $objdb->insert_doc(-parent => $support2_name_id,
		       -content => "Parent $_",
		       -Title => "parent $_",
		      );
}

waitpid($pid, 0);
ok($?, 0, "Child returned with non-zero value");

{
    my $integrity_check = $objdb->check_integrity;
    ok($integrity_check->has_errors, 0, "Integrity check");
    if ($integrity_check->has_errors) {
	require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	    Data::Dumper->new([$integrity_check],[])->Indent(1)->Useqq(1)->Dump;
    }
}

{
    my $integrity_check2 = $r->ContentDB->check_integrity($objdb);
    ok($integrity_check2->has_errors, 0, "Integrity check for ContentDB");
    if ($integrity_check2->has_errors) {
	require Data::Dumper;
	print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	    Data::Dumper->new([$integrity_check2],[])->Indent(1)->Useqq(1)->Dump;
    }
}

sub child {
    scalar <RDR>; # wait for "connected" message from parent
    scalar <RDR>; # wait from "disconnected" message from parent
    close RDR;

    my $r = new WE::DB -class => 'WE_Sample::Root',
	               -rootdir => $testdir,
                       -locking => 1,
                       -connect => 0;
    my $objdb = $r->ObjDB;

    my $support2_name_id = $objdb->name_to_objid("support2_name");
    die "Can't find object with name support2_name in database"
	if !defined $support2_name_id;

    for(1..100) {
	$objdb->insert_doc(-parent => $support2_name_id,
			   -content => "Child $_",
			   -Title => "child $_",
			  );
    }
}

__END__
