#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 93_nullfilter.t,v 1.2 2004/04/05 20:31:12 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use vars qw($confdir);

use WE_Sample::Root;
use WE::Util::LangString qw(langstring);
BEGIN {
    $confdir = "$FindBin::RealBin/conf/new_publish_ftp";
}
use lib $confdir; # for WEsiteinfo.pm
use WE_Frontend::Main2;
use WEsiteinfo qw($c);

BEGIN {
    if (!eval q{
	use Test;
	use Template 2.09; # because of modern "DEBUG" directive
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test and Template 2.09 modules\n";
	exit;
    }
}

# depends on: recent runs of 90_sample.t and 92_support.t
# XXX check automatically for this dependency (?)

BEGIN { plan tests => 2 }

my $testdir = "$FindBin::RealBin/test";
my $r = new WE_Sample::Root -rootdir => $testdir,
                            -connect => 1;
my $objdb = $r->{ObjDB};
my $objid = $objdb->name_to_objid("named_object");

my $text1 = <<'EOF';
[% USE NullFilter -%]
[% FILTER $NullFilter -%]
unfiltered text
[% END -%]
[% "unfiltered text" | $NullFilter %]
EOF

my $oktext1 = <<'EOF';
unfiltered text
unfiltered text
EOF

my $t1 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
my $output1;
my $ret1 = $t1->process(\$text1, {objdb => $objdb,
				  objid => $objid,
				  langstring => \&langstring}, \$output1);
ok($ret1, 1, $t1->error);
ok($output1, $oktext1);
if ($output1 ne $oktext1) {
    show_diff($oktext1, $output1);
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
