#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 92_support.t,v 1.2 2003/06/13 21:18:40 eserte Exp $
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

BEGIN { plan tests => 37 }

my $testdir = "$FindBin::RealBin/test";
ok(-d $testdir, 1);
ok(-w $testdir, 1);

my $r = new WE::DB -class => 'WE_Sample::Root', -rootdir => $testdir;
ok(ref $r, 'WE_Sample::Root');
my $objdb = $r->ObjDB;
ok(ref $objdb, 'WE::DB::Obj');

# Please make sure that "Support 1/1" has only *one* children for the
# navigation_plugin.t test!
$objdb->create_folder_tree(-standardargs => {-Rights => 'All rights'},
			   -string => <<'EOF');
-Title "Support 1" -Rights "No rights" -Name norights
 -Title "Support 1/1" -Name only_one_child
  -Title "Support 1/1/1" -Name child_of_only_one_child
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

eval {
    $objdb->create_folder_tree(-string => <<'EOF');
-Title "en:Error no dash" Rights "No rights"
EOF
};
ok($@ =~ /Parse error/i, 1);

my $oid1 = $objdb->name_to_objid("support21_name");
my $oid2 = $objdb->name_to_objid("support211_name");
my $oid3 = $objdb->name_to_objid("norights");
ok(defined $oid1, 1);
ok(defined $oid2, 1);
ok(defined $oid3, 1);
ok(($objdb->parent_ids($oid2))[-1], $oid1);
my $o1 = $objdb->get_object($oid1);
my $o3 = $objdb->get_object($oid3);
ok($o1->Rights, 'All rights');
ok($o3->Rights, 'No rights');

{
    # check change_order

    my $p = $objdb->name_to_objid("support2_name");
    ok(defined $p, 1);

    my(@p_c) = $objdb->children_ids($p);
    ok(scalar @p_c, 6);

    # try to change order
    my @new_p_c = reverse @p_c;
    $objdb->change_order($p, \@new_p_c);
    my(@p_c_2) = $objdb->children_ids($p);
    ok(scalar @p_c_2, 6);
    ok(join(",",@new_p_c), join(",",@p_c_2));

    # now with some error conditions:
    my(@new_p_c_2, @p_c_3);
    {
	my $warning_seen;
	local $SIG{__WARN__} = sub { $warning_seen++ };

	@new_p_c_2 = @p_c;
	my $shifted_id = shift @new_p_c_2; # leave the object 2/6
	$objdb->change_order($p, \@new_p_c_2);
	ok($warning_seen);
	@p_c_3 = $objdb->children_ids($p);
	ok(scalar @p_c_3, 6);
	ok(join(",",@new_p_c_2,$shifted_id), join(",",@p_c_3));
    }

    my(@new_p_c_3) = @p_c;
    push @new_p_c_3, 987654321; # non existing id
    eval {
	$objdb->change_order($p, \@new_p_c_3);
    };
    ok($@ ne "", 1);
    my(@p_c_4) = $objdb->children_ids($p);
    ok(scalar @p_c_4, 6);
    ok(join(",",@p_c_4), join(",",@p_c_3));

    # again reversed to see the effect in we_dump
    $objdb->change_order($p, \@new_p_c);

}

{
    # check get_position_array

    my $p = $objdb->name_to_objid("support2122_name");
    ok(defined $p, 1);
    my(@position_array) = $objdb->get_position_array($p);
    shift @position_array; # throw the first away, because things can change in 90_sample.t
    ok(join(",",@position_array), "5,1,1");

    my @position_array2 = $objdb->get_position_array($p, -base => 1);
    shift @position_array2;
    ok(join(",",@position_array2), "6,2,2");

    # now create two docs and check get_position_array of them
    my $doc = $objdb->insert_doc(-content => "This is some content",
				 -parent => $p,
				 -Title => "First doc");
    ok(defined $doc, 1);
    my $doc2 = $objdb->insert_doc(-content => "This is the 2nd content",
				  -parent => $p,
				  -Title => "Second doc");
    ok(defined $doc2, 1);

    my @doc_position_array = $objdb->get_position_array($doc);
    my $doc_pos = pop @doc_position_array;
    ok($doc_pos, 0);
    shift @doc_position_array;
    ok(join(",", @position_array), join(",",@doc_position_array));

    @doc_position_array = $objdb->get_position_array($doc2);
    $doc_pos = pop @doc_position_array;
    ok($doc_pos, 1);
    shift @doc_position_array;
    ok(join(",", @position_array), join(",",@doc_position_array));

    # filter?
    my $filter_released = sub {
	my($objdb, $children_id) = @_;
	my $o = $objdb->get_object($children_id);
	#return 1 if ($o->is_folder);
	if (!defined $o->Release_State || $o->Release_State eq '') {
	    1;
	} else {
	    0;
	}
    };

    @position_array = $objdb->get_position_array($p, -filter => $filter_released);
    shift @position_array; # throw the first away, because things can change in 90_sample.t
    ok(join(",",@position_array), "5,1,0");

    my $p_obj = $objdb->get_object($p);
    ok(defined $p_obj, 1);
    ok(!defined $p_obj->{IndexDoc}, 1);
    $p_obj->{IndexDoc} = $doc->Id;
    $objdb->replace_object($p_obj);
    $p_obj = $objdb->get_object($p);
    ok(defined $p_obj, 1);
    ok($p_obj->{IndexDoc}, $doc->Id);

    @position_array = $objdb->get_position_array($doc->Id);
    ok(join(" ",@position_array), "5 5 1 1 0");
    @position_array = $objdb->get_position_array($doc->Id, -indexdoc => 1);
    ok(join(" ",@position_array), "5 5 1 1");
}

__END__
