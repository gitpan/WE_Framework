#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 93_htmlnum_filter.t,v 1.2 2005/01/30 08:29:31 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test::More;
	use Template 2.09; # because of modern "DEBUG" directive
	use HTML::Entities 1.27; # see WE_Frontend::Plugin::HtmlNum
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test::More and Template 2.09 modules\n";
	exit;
    }
}

plan tests => 4;

my $text1 = <<'EOF';
[% USE HtmlNum -%]
[% FILTER html_num -%]
abcäöüßxyz
[% END -%]
[% "abcäöüßxyz" | html_num %]
[% "abcäöüßxyz" | $HtmlNum %][%# old syntax %]
EOF

my $oktext1 = <<'EOF';
abc&#xE4;&#xF6;&#xFC;&#xDF;xyz
abc&#xE4;&#xF6;&#xFC;&#xDF;xyz
abc&#xE4;&#xF6;&#xFC;&#xDF;xyz
EOF

my $t1 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
my $output1;
my $ret1 = $t1->process(\$text1, { }, \$output1);
ok($ret1) or diag($t1->error);
is($output1, $oktext1);
if ($output1 ne $oktext1) {
    show_diff($oktext1, $output1);
}

# Test utf-8 characters
SKIP: {
    my $eurosign;
    eval q{
	use charnames qw(:full);
	$eurosign = "\N{EURO SIGN}";
    };
    skip "No utf8 support", 1 if !defined $eurosign;
    
    my $text2 = <<EOF;
[% USE HtmlNum -%]
[% "ä$eurosign" | html_num %]
EOF
    my $oktext2 = <<'EOF';
&#xE4;&#x20AC;
EOF

    my $output2;
    my $ret2 = $t1->process(\$text2, { }, \$output2);
    ok($ret2) or diag($t1->error);
    is($output2, $oktext2);
    if ($output2 ne $oktext2) {
	show_diff($oktext2, $output2);
    }
    
}

######################################################################
sub show_diff {
    my($s1,$s2) = @_;
    my $tmpdir = tmpdir();
    my $base   = "$tmpdir/test.$$";

    open(S1, ">$base.1") or die $!;
    print S1 $s1;
    close S1;
    open(S2, ">$base.2") or die $!;
    print S2 $s2;
    close S2;

    open(DIFF, "diff -u $base.1 $base.2 |");
    while(<DIFF>) {
	print "# $_";
    }
    close DIFF;

    unlink "$base.1";
    unlink "$base.2";
}

# REPO BEGIN
# REPO NAME tmpdir /home/e/eserte/src/repository 
# REPO MD5 c41d886135d054ba05e1b9eb0c157644

=head2 tmpdir()

=for category File

Return temporary directory for this system. This is a small
replacement for File::Spec::tmpdir.

=cut

sub tmpdir {
    foreach my $d ($ENV{TMPDIR}, $ENV{TEMP},
		   "/tmp", "/var/tmp", "/usr/tmp", "/temp") {
	next if !defined $d;
	next if !-d $d || !-w $d;
	return $d;
    }
    undef;
}
# REPO END

__END__
