#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 22_permissions.t,v 1.5 2004/10/11 22:10:25 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::Util::Permissions;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 78 }

my $p0 = WE::Util::Permissions->new(-string => <<EOF);
# Nobody is allowed to do anything
EOF
is(ref $p0, 'WE::Util::Permissions', "Permissions object ok");
ok(!$p0->is_allowed(-user => "eserte", -process => "delete"), "empty permissions file");

######################################################################
my $p1 = WE::Util::Permissions->new(-string => <<EOF);
# Das hier ist ein Test
		# comment after tabs

user eserte, ole; group wheel
 process login save           # embedded comment
user root
 process *
user hotel_a
 process login
  page hotel_a
 process save
  page hotel_a1
user eserte
 page *
  process blubber
EOF

my $tmp = "$FindBin::RealBin";

is(ref $p1, 'WE::Util::Permissions');
$p1->save("$tmp/permissions_test");
ok(-f "$tmp/permissions_test", "saving permissions_test");
is($p1->is_allowed(-user => "eserte", -process => "save"), 1);
is(!$p1->is_allowed(-user => "eserte", -process => "delete"), 1);
is($p1->is_allowed(-user => "wheely", -group => ['wheel'], -process => "save"), 1);
is(!$p1->is_allowed(-user => "hotel_a", -process => "save", -page => 'hotel_a'), 1);
is(!$p1->is_allowed(-user => "hotel_a", -process => "login", -page => 'hotel_a1'), 1);

my $all_users = {eserte   => ['editor','wheel'],
		 ole      => ['editor'],
		 wheely   => ['wheel'],
		 dummy    => [],
		 hotel_a  => [],
		 hotel_a1 => [],
		 root     => ['editor','wheel','admin']};
is(join(",", sort $p1->get_all_users($all_users, "login")), "eserte,ole,root,wheely");
is(join(",", sort $p1->get_all_users($all_users, "save")), "eserte,ole,root,wheely");
is(join(",", sort $p1->get_all_users($all_users, "anything")), "root");
is(join(",", sort $p1->get_all_users($all_users, "login", "hotel_a")), "eserte,hotel_a,ole,root,wheely");
is(join(",", sort $p1->get_all_users($all_users, "blubber", "xyz")), "eserte,root");

my $all_processes = [qw(login save admin blubber)];
my $info = $p1->get_all_page_permissions($all_users, $all_processes, "hotel_a");
is(join(",", sort @{ $info->{'admin'} }), "root");
is(join(",", sort @{ $info->{'save'} }), "eserte,ole,root,wheely");
is(join(",", sort @{ $info->{'login'} }), "eserte,hotel_a,ole,root,wheely");
is(join(",", sort @{ $info->{'blubber'} }), "eserte,root");

######################################################################
my $p2 = WE::Util::Permissions->new(-string => <<EOF);
# real world test
process publish
 group chefredakteur
process save
 group chefredakteur author
EOF

my %user_data1 = (-user => 'eserte', -group => 'author');
my %user_data2 = (-user => 'root', -group => ['author', 'chefredakteur']);

is(ref $p2, 'WE::Util::Permissions', "real world test");
ok(!$p2->is_allowed(%user_data1, -process => 'publish'));
ok($p2->is_allowed(%user_data1, -process => 'save'));
ok($p2->is_allowed(%user_data2, -process => 'publish'));
ok($p2->is_allowed(%user_data2, -process => 'save'));

######################################################################
my $p3 = WE::Util::Permissions->new(-string => <<EOF);
# test with restricted pages
user eserte; group */chefredakteur, group1/*
 page *
user hotel1
 page hotels/hotel1/*
  process !publish *
user hotel2
 page hotels/hotel2/*
  process !publish *
EOF

is(ref $p3, 'WE::Util::Permissions', "test with restricted pages");
ok($p3->is_allowed(-user => "eserte",
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));

# tests for pseudo group/role syntax
ok($p3->is_allowed(-user => "xyz",
		   -group => ['group2/chefredakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok($p3->is_allowed(-user => "xyz",
		   -group => ['group1/chefredakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok(!$p3->is_allowed(-user => "xyz",
		    -group => ['group2/chefredakteur_no'],
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok($p3->is_allowed(-user => "xyz",
		   -group => ['group1/redakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok(!$p3->is_allowed(-user => "xyz",
		    -group => ['group2/redakteur'],
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));

ok($p3->is_allowed(-user => "hotel1",
		   -page => "hotels/hotel1/bla",
		   -process => 'save'));
ok(!$p3->is_allowed(-user => "hotel1",
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok(!$p3->is_allowed(-user => "hotel2",
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok($p3->is_allowed(-user => "hotel2",
		   -page => "hotels/hotel2/bla",
		   -process => 'save'));
ok(!$p3->is_allowed(-user => "hotel2",
		    -page => "hotels/hotel2/bla",
		    -process => 'publish'));
ok(!$p3->is_allowed(-user => "hotel1",
		    -page => "hotels/hotel2/bla",
		    -process => 'publish'));

######################################################################
my $p4 = WE::Util::Permissions->new(-string => <<EOF);
# test with regular expressions
! match: regexp
user eserte; group .*/chefredakteur, group1/.*, group3/(chefredakteur|meister)
 page .*
user hotel1
 page hotels/hotel1/.*
  process !publish .*
user hotel2
 page hotels/hotel2/.*
  process !publish .*
EOF

is(ref $p4, 'WE::Util::Permissions', "test with regular expressions");
is(ref $p4->{Directives}, 'HASH');
is($p4->{Directives}{'match'}, "regexp", "match type is regexp");

ok($p4->is_allowed(-user => "eserte",
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));

# tests for pseudo group/role syntax
ok($p4->is_allowed(-user => "xyz",
		   -group => ['group2/chefredakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok($p4->is_allowed(-user => "xyz",
		   -group => ['group1/chefredakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok(!$p4->is_allowed(-user => "xyz",
		    -group => ['group2/chefredakteur_no'],
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok($p4->is_allowed(-user => "xyz",
		   -group => ['group1/redakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok(!$p4->is_allowed(-user => "xyz",
		    -group => ['group2/redakteur'],
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok($p4->is_allowed(-user => "xyz",
		   -group => ['group3/chefredakteur'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok($p4->is_allowed(-user => "xyz",
		   -group => ['group3/meister'],
		   -page => "hotels/hotel1/bla",
		   -process => 'publish'));
ok(!$p4->is_allowed(-user => "xyz",
		    -group => ['group3/lehrling'],
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));

ok($p4->is_allowed(-user => "hotel1",
		   -page => "hotels/hotel1/bla",
		   -process => 'save'));
ok(!$p4->is_allowed(-user => "hotel1",
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok(!$p4->is_allowed(-user => "hotel2",
		    -page => "hotels/hotel1/bla",
		    -process => 'publish'));
ok($p4->is_allowed(-user => "hotel2",
		   -page => "hotels/hotel2/bla",
		   -process => 'save'));
ok(!$p4->is_allowed(-user => "hotel2",
		    -page => "hotels/hotel2/bla",
		    -process => 'publish'));
ok(!$p4->is_allowed(-user => "hotel1",
		    -page => "hotels/hotel2/bla",
		    -process => 'publish'));


######################################################################
# test with illegal match directive
my $p5 = WE::Util::Permissions->new(-string => <<EOF);
! match: gibsnich
user eserte; group .*/chefredakteur, group1/.*, group3/(chefredakteur|meister)
EOF

is(ref $p5, 'WE::Util::Permissions');
eval { $p5->is_allowed(-user => "eserte",
		       -page => "hotels/hotel1/bla",
		       -process => 'publish') };
isnt($@, "", "illegal match directive");

######################################################################
# test with illegal regular expressions
my $p6 = WE::Util::Permissions->new(-string => <<EOF);
! match: regexp
user )eserte; group .*/chefredakteur, group1/.*, group3/(chefredakteur|meister)
EOF

is(ref $p6, 'WE::Util::Permissions');
eval { $p6->is_allowed(-user => "eserte",
		       -page => "hotels/hotel1/bla",
		       -process => 'publish') };
isnt($@, "", "illegal regexp");

######################################################################
# a simple real world example
my $p7 = WE::Util::Permissions->new(-string => <<EOF);
! match: glob
group admin
group chiefeditor
 process !admin !useradmin *
group editor
 process !publish !admin !useradmin *
group guest
 process !publish !admin !useradmin !edit *
group *
 process !*
EOF

is(ref $p7, 'WE::Util::Permissions', "a simple real world example");
ok($p7->is_allowed(-group => ['admin'],
		   -process => 'publish'));
ok(!$p7->is_allowed(-group => ['editor'],
		    -process => 'publish'));
ok(!$p7->is_allowed(-group => ['editor'],
		    -process => 'admin'));
ok($p7->is_allowed(-group => ['editor'],
		   -process => 'edit'));
ok(!$p7->is_allowed(-group => ['guest'],
		    -process => 'admin'));
ok(!$p7->is_allowed(-group => ['guest'],
		    -process => 'edit'));
ok($p7->is_allowed(-group => ['guest'],
		   -process => 'read'));
ok(!$p7->is_allowed(-group => ['foobar'],
		    -process => 'edit'));
ok(!$p7->is_allowed(-group => ['foobar'],
		    -process => 'read'));
ok(!$p7->is_allowed(-group => ['editor'],
		    -process => 'useradmin'));
ok(!$p7->is_allowed(-group => ['editor'],
		    -process => ['useradmin']));
#XXX think of these...
#ok($p7->is_allowed(-group => ['guest'], -process => ['read','useradmin']));
#ok($p7->is_allowed(-group => ['guest'], -process => ['read','useradmin','admin']));
ok(!$p7->is_allowed(-group => ['foobar'],
		    -process => ['read','useradmin']));
ok(!$p7->is_allowed(-group => ['chiefeditor'],
		    -process => ['admin','useradmin']));
#ok($p7->is_allowed(-group => ['chiefeditor'],  -process => ['admin','useradmin','release']));

######################################################################
# And now fixed bugs...
{
    my $p = WE::Util::Permissions->new(-string => <<EOF);
! match: glob
group admin
 process *
group chiefeditor
 process release publish edit new-doc new-folder
group editor
 process edit
group handset-matrix-editor
 page /Handset?Matrix/*
  process edit release
group *
 process !*
EOF

    is(ref $p, 'WE::Util::Permissions');
    ok($p->is_allowed(-user => "test",
		      -group => ["handset-matrix-editor"],
		      -page => "/Handset Matrix/Handset Matrix.bin",
		      -process => 'edit',
		     ));
}

{
    my $p = WE::Util::Permissions->new(-string => <<EOF);
! match: regexp
group admin
 process .*
group chiefeditor
 process release publish edit new-doc new-folder
group editor
 process edit
group handset-matrix-editor
 page /Handset.Matrix/.*
  process edit release
group .*
 process !.*
EOF

    is(ref $p, 'WE::Util::Permissions');
    ok($p->is_allowed(-user => "test",
		      -group => ["handset-matrix-editor"],
		      -page => "/Handset Matrix/Handset Matrix.bin",
		      -process => 'edit',
		     ));
}

{
    eval {
	my $p = WE::Util::Permissions->new(-string => <<EOF);
! match: regexp
group admin
 process .*
! match: glob
group chiefeditor
 process release publish edit new-doc new-folder
EOF
    };
    like($@, qr/multiple match/);
}

{
    my $p = WE::Util::Permissions->new(-string => <<EOF);
! primarylang: de
group admin
 path /foo/bar
  process .*
EOF
    is($p->get_directive("primarylang"), "de", "primarylang directive");
}

END {
    unlink "$tmp/permissions_test"
	if defined $tmp && -e "$tmp/permissions_test";
}

__END__
