#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 94_js_plugin.t,v 1.6 2004/12/12 11:40:47 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use Template;
	use JavaScript;
	1;
    }) {
	print "# tests only work with installed Test, Template, and JavaScript modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 11 }

my $runtime = new JavaScript::Runtime();
my $context = $runtime->create_context();

######################################################################
# all characters
{
    my $text = <<EOF;
[%- USE JS -%]
var s1 = '[%- all_characters | js_q -%]';
var s2 = "[%- all_characters | js_q -%]";
var s3 = s1 + s2;
s3;
EOF

    my $all_characters = join("", map { chr($_) } (8,9,10,12,13,32..126,160..255));

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
    my $output;
    my $ret = $t->process(\$text, {all_characters => $all_characters}, \$output);
    ok($ret, "js_q test") or diag $t->error;

    my $js_ret = $context->eval($output);
    is($js_ret, $all_characters . $all_characters,
       "js_q test through libjs");
}

######################################################################
# real life test
{
    my $text = <<EOF;
[%- USE JS -%]
var s1 = "[% 'Seite "Foobar" erfolgreich gespeichert.' | js_q %]";
var s2 = '[% 'Seite "Foobar" erfolgreich gespeichert.' | js_q %]';
var s3 = s1 + s2;
s3
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
    my $output;
    my $ret = $t->process(\$text, {}, \$output);
    ok($ret, "real js_q test") or diag $t->error;

    my $js_ret = $context->eval($output);
    is($js_ret, "Seite \"Foobar\" erfolgreich gespeichert."x2,
       "real js_q test thorugh libjs");
}

{
    my $text = <<EOF;
[%- USE JS -%]
var s1 = unescape("[% 'Seite "Foobar" erfolgreich gespeichert.' | js_escape %]");
s1
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
    my $output;
    my $ret = $t->process(\$text, {}, \$output);
    ok($ret, "js_escape test") or diag $t->error;

    my $js_ret = $context->eval($output);
    is($js_ret, "Seite \"Foobar\" erfolgreich gespeichert.",
       "js_escape test through libjs");
}

{
    my $text = <<EOF;
[%- USE JS -%]
[% "Euro \x{20ac}" | js_escape %]
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
    my $output;
    my $ret = $t->process(\$text, {}, \$output);
    ok($ret, "js_escape with unicode test") or diag $t->error;
    is($output, <<EOF);
Euro%20%u20ac
EOF
}

{
    my $text = <<EOF;
[%- USE JS -%]
var a1 = "[%- FILTER js_uni -%]
normal characters:    ABC
umlauts in latin1:    \xe4\xf6\xfc
unicode range (euro): \x{20ac}
[% END -%]";
a1
EOF
    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
    my $output;
    my $ret = $t->process(\$text, {}, \$output);
    ok($ret, "js_uni test") or diag $t->error;

    is($output, <<'EOF', "correct javascript output");
var a1 = "normal characters:    ABC\numlauts in latin1:    \u00e4\u00f6\u00fc\nunicode range (euro): \u20ac\n";
a1
EOF

    local $TODO = "libjs seems to have problems with unicode";
    my $js_ret = $context->eval($output);
    is($js_ret, <<EOF, "js_uni test through libjs");
normal characters:    ABC
umlauts in latin1:    \xe4\xf6\xfc
unicode range (euro): \x{20ac}
EOF
}

######################################################################
#kann wech XXX
#  my $x=qq{x = "init('Seite \x5c"Foobar\x5c" erfolgreich gespeichert und freigegeben.'); x;"};
#  warn $context->eval($x);

__END__
