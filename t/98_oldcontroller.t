#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 98_oldcontroller.t,v 1.3 2005/01/30 08:29:31 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use WebEditor::OldController;

BEGIN {
    if (!eval q{
	use Test::More;
	use Data::JavaScript;
	1;
    }) {
	print "ok 1 # skip tests only work with installed Test::More and Data::JavaScript modules\n";
	exit;
    }
}

plan tests => 2;

my $oc = WebEditor::OldController->new;
ok($oc);

SKIP: {
    my $s = eval q{
	use charnames ":full";
	join("", map { chr } 0 .. 255) . "\N{EURO SIGN}";
    };
    skip "No utf8 support available", 1
	if !defined $s;

    is(WebEditor::OldController::_uri_escape($s)."\n", <<'EOF');
%00%01%02%03%04%05%06%07%08%09%0A%0B%0C%0D%0E%0F%10%11%12%13%14%15%16%17%18%19%1A%1B%1C%1D%1E%1F%20!%22%23%24%25%26'()*%2B%2C-.%2F0123456789%3A%3B%3C%3D%3E%3F%40ABCDEFGHIJKLMNOPQRSTUVWXYZ%5B%5C%5D%5E_%60abcdefghijklmnopqrstuvwxyz%7B%7C%7D~%7F%80%81%82%83%84%85%86%87%88%89%8A%8B%8C%8D%8E%8F%90%91%92%93%94%95%96%97%98%99%9A%9B%9C%9D%9E%9F%A0%A1%A2%A3%A4%A5%A6%A7%A8%A9%AA%AB%AC%AD%AE%AF%B0%B1%B2%B3%B4%B5%B6%B7%B8%B9%BA%BB%BC%BD%BE%BF%C0%C1%C2%C3%C4%C5%C6%C7%C8%C9%CA%CB%CC%CD%CE%CF%D0%D1%D2%D3%D4%D5%D6%D7%D8%D9%DA%DB%DC%DD%DE%DF%E0%E1%E2%E3%E4%E5%E6%E7%E8%E9%EA%EB%EC%ED%EE%EF%F0%F1%F2%F3%F4%F5%F6%F7%F8%F9%FA%FB%FC%FD%FE%FF%u20ac
EOF
}

__END__
