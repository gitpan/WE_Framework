#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 92_support2.t,v 1.3 2002/09/30 11:57:40 eserte Exp $
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

BEGIN { plan tests => 9 }

my $testdir = "$FindBin::RealBin/test2";
ok(-d $testdir, 1);
ok(-w $testdir, 1);

my $r = new WE::DB -class => 'WE_Sample::Root', -rootdir => $testdir;
ok(ref $r, 'WE_Sample::Root');
my $objdb = $r->ObjDB;
ok(ref $objdb, 'WE::DB::Obj');
$objdb->delete_db_contents;
$r->ContentDB->delete_db_contents;

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

my $support2_name_id = $objdb->name_to_objid("support2_name");
for (1..10) {
    $objdb->insert_doc(-parent => $support2_name_id,
		       -content => $_,
		       -Title => "Title: $_",
		       -Name => "document $_",
		      );
}
ok($objdb->dump, qr|d Root of the site                                 \(none\)   .*    0
 d Support 1                                       \(none\)   .*    1
  d Support 1/1                                    \(none\)   .*    2
   d Support 1/1/1                                 \(none\)   .*    3
  d Support 1/2                                    \(none\)   .*    4
 d Support 2                                       \(none\)   .*    5
  d Support 2/1                                    \(none\)   .*    6
   d Support 2/1/1                                 \(none\)   .*    7
    d Support 2/1/1/1                              \(none\)   .*    8
   d Support 2/1/2                                 \(none\)   .*    9
    d Support 2/1/2/1                              \(none\)   .*   10
    d Support 2/1/2/2                              \(none\)   .*   11
  d Support 2/2                                    \(none\)   .*   12
   d Support 2/2/1                                 \(none\)   .*   13
  d Support english 2/3                            \(none\)   .*   14
  d xxx:Support 2/4 no lang                        \(none\)   .*   15
  d Support english 2/5                            \(none\)   .*   16
  d Support 2/6                                    \(none\)   .*   17
  - Title: 1                                       \(none\)   .*   18
  - Title: 2                                       \(none\)   .*   19
  - Title: 3                                       \(none\)   .*   20
  - Title: 4                                       \(none\)   .*   21
  - Title: 5                                       \(none\)   .*   22
  - Title: 6                                       \(none\)   .*   23
  - Title: 7                                       \(none\)   .*   24
  - Title: 8                                       \(none\)   .*   25
  - Title: 9                                       \(none\)   .*   26
  - Title: 10                                      \(none\)   .*   27
|);

# remove was never tested
my $doc_5_id = $objdb->name_to_objid("document 5");
$objdb->remove($doc_5_id);
ok($objdb->dump, qr|d Root of the site                                 \(none\)   .*    0
 d Support 1                                       \(none\)   .*    1
  d Support 1/1                                    \(none\)   .*    2
   d Support 1/1/1                                 \(none\)   .*    3
  d Support 1/2                                    \(none\)   .*    4
 d Support 2                                       \(none\)   .*    5
  d Support 2/1                                    \(none\)   .*    6
   d Support 2/1/1                                 \(none\)   .*    7
    d Support 2/1/1/1                              \(none\)   .*    8
   d Support 2/1/2                                 \(none\)   .*    9
    d Support 2/1/2/1                              \(none\)   .*   10
    d Support 2/1/2/2                              \(none\)   .*   11
  d Support 2/2                                    \(none\)   .*   12
   d Support 2/2/1                                 \(none\)   .*   13
  d Support english 2/3                            \(none\)   .*   14
  d xxx:Support 2/4 no lang                        \(none\)   .*   15
  d Support english 2/5                            \(none\)   .*   16
  d Support 2/6                                    \(none\)   .*   17
  - Title: 1                                       \(none\)   .*   18
  - Title: 2                                       \(none\)   .*   19
  - Title: 3                                       \(none\)   .*   20
  - Title: 4                                       \(none\)   .*   21
  - Title: 6                                       \(none\)   .*   23
  - Title: 7                                       \(none\)   .*   24
  - Title: 8                                       \(none\)   .*   25
  - Title: 9                                       \(none\)   .*   26
  - Title: 10                                      \(none\)   .*   27
|);

$objdb->remove($support2_name_id);
ok($objdb->dump, qr|d Root of the site                                 \(none\)   .*    0
 d Support 1                                       \(none\)   .*    1
  d Support 1/1                                    \(none\)   .*    2
   d Support 1/1/1                                 \(none\)   .*    3
  d Support 1/2                                    \(none\)   .*    4
|);

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

__END__
