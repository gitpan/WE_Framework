#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 01_we_obj.t,v 1.2 2004/06/07 06:58:55 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use WE::Obj;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 21 }

my $o = new WE::Obj;
is(ref $o, 'WE::Obj');
$o->Id(1);
is($o->Id, 1);
$o->Title("Bla");
is($o->Title, "Bla");
my $o2 = $o->clone;
isnt("$o", "$o2");
is($o2->Title, "Bla");
is($o2->Id, 1);
$o2->Id(2);
is($o2->Id, 2);
is($o->Id, 1);

for my $field (qw(TimeCreated TimeOpen TimeExpire)) {
    is($o->field_is_date($field), 1, "$field is a date field");
}
is($o->field_is_date("Owner"), 0);
is($o->field_is_user("Owner"), 1);
is($o->field_is_user("TimeCreated"), 0);
is($o->field_is_not_editable("Id"), 1);
is($o->field_is_not_editable("TimeCreated"), 0);

$o->TimeOpen("2000-01-01 00:00:00");
$o->TimeExpire("2200-01-01 00:00:00");
is($o->TimeOpen, "2000-01-01 00:00:00", "TimeOpen");
is($o->TimeExpire, "2200-01-01 00:00:00", "TimeExpire");
ok(!$o->is_time_restricted, "Not time restricted");
ok($o->is_time_restricted("1999-01-01 00:00:00"));
ok($o->is_time_restricted("2201-01-01 00:00:00"));

__END__
