#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 21_langstring.t,v 1.2 2002/12/12 21:57:28 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use WE::Util::LangString qw(langstring new_langstring set_langstring);

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

BEGIN { plan tests => 24 }

ok(ref new_langstring() eq 'WE::Util::LangString', 1);
ok(ref WE::Util::LangString->new eq 'WE::Util::LangString', 1);
my $l = new_langstring(en => "english", de => "german");
ok($l->isa('WE::Util::LangString'), 1);
ok(langstring($l, "en"), "english");
ok(langstring($l, "de"), "german");
ok(langstring($l), "english");
ok(langstring($l, "foo",), "english");
ok($l->get("en"), "english");
ok($l->get, "english");
ok(langstring("foobar", "en"), "foobar");
ok(langstring("foobar"), "foobar");
set_langstring($l, "hr", "hrvatski");
ok($l->get, "english");
ok($l->get("hr"), "hrvatski");
my $foo = "foobar";
ok(langstring($foo), "foobar");
set_langstring($foo, "de", "blubber");
ok($foo->get, "foobar");
ok($foo->get("en"), "foobar");
ok($foo->get("de"), "blubber");
my $foo2 = "foobar2";
ok(langstring($foo2), "foobar2");
set_langstring($foo2, "de", "blubber", "hr");
ok($foo2->get("hr"), "foobar2");
ok($foo2->get("de"), "blubber");
ok($foo2->dump, "de: blubber, hr: foobar2");
my $foo3;
set_langstring($foo3, "de", "german");
set_langstring($foo3, "en", undef);
ok($foo3->get("de"), "german");
ok($foo3->get("en"), undef);
ok($foo3->dump, "de: german, en: (undef)");

__END__
