#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 97_ftp_md5sync_publish.t,v 1.3 2003/08/17 19:57:28 eserte Exp $
# Author: Slaven Rezic
#

# XXX This test should be rewritten.

use strict;
use vars qw($tests $pretests);

use FindBin;
use lib "$FindBin::RealBin/conf/publish_ftp_md5sync"; # for WEsiteinfo.pm
use WE_Frontend::Main;
use WEsiteinfo;
use File::Copy qw(cp);
use File::Basename;

BEGIN {
    if (!eval q{
	use Test;
	use Net::Domain qw(hostdomain);
	die "Not here" if hostdomain ne "intra.onlineoffice.de";
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    $pretests = 5 + 7*5;
    $tests = 38;
}

BEGIN { plan tests => $pretests+$tests }

use vars qw($fe $stagingdir $cgidir);
$fe = new WE_Frontend::Main undef;
ok($fe->isa('WE_Frontend::Main'), 1);

$stagingdir = $WEsiteinfo::livedirectory;
$cgidir     = $WEsiteinfo::livecgidirectory;

my $md5script = "$FindBin::RealBin/../cgi-scripts/get_md5_list.cgi";
ok(-f $md5script);
ok(-x $md5script);
my $c_r;
{
    require File::Spec;
    *OLDERR = *OLDERR;
    open(OLDERR, ">&STDERR");
    open(STDERR, ">" . File::Spec->devnull);
    $c_r = system($^X, "-c", $md5script)/256;
    close STDERR;
    open(STDERR, ">&OLDERR");
}
ok($c_r, 0);
mkdir "$FindBin::RealBin/cgi-bin", 0755 if !-d "$FindBin::RealBin/cgi-bin";
my $md5script2 = "$FindBin::RealBin/cgi-bin/" . basename $md5script;
unlink $md5script2;
cp($md5script, $md5script2);
chmod 0755, $md5script2;
ok(-x $md5script2);

# This is created manually, because MANIFEST cannot contain files with
# spaces.
open(F, ">$FindBin::RealBin/content/evil file with 'spaces\".txt")
    or die $!;
close F;

foreach my $digest_method
    (['perl:Digest::MD5', sub { eval 'require Digest::MD5; 1' } ],
     ['perl:MD5', sub { eval 'require MD5; 1' } ],
     ['cmd:md5', sub { is_in_path("md5") } ],
     ['cmd:md5sum', sub { is_in_path("md5sum") } ],
     ['perl:Digest::Perl::MD5', sub { eval 'require Digest::Perl::MD5; 1' } ],
     ['cmd:cksum', sub { 0 && is_in_path("cksum") } ], # skip now
     ['stat:modtime', sub { 1 }],
    ) {
    my($method, $test) = @$digest_method;
    if ($test->()) {
	open(CONFIG, ">$md5script2.config") or die "Can't create config file: $!";
	print CONFIG "\@digest_method=\"$method\"; \@directories=\"$FindBin::RealBin/content\";\n";
	close CONFIG;
	my(@output) = `$^X $md5script2 ""`;
	my $contenttype = shift @output;
	ok($contenttype =~ m|Content-Type:\s*text/plain|i, 1,
	   "Unexpected content type: $contenttype");
	shift @output;
	my $digest = shift @output;
	ok($digest =~ /digest:/i, 1, "No `digest' in $digest");
	my $method = shift @output;
	ok($method =~ /method:/i, 1, "No `method' in $method");
	my $directory = shift @output;
	ok($directory =~ m|t/content$|, 1, "Unexpected directory `$directory'");
	if ($digest =~ /md5/i) {
	    my @output = grep { $_ !~ /^CVS\// } @output;
	    ok(join("", sort @output), <<'EOF', "with method $method");
empty_product.bin	03a35a23b8b9976e178816936336c2a8
empty_product_added.bin	311092c392282bcfb80f20fe1ab8aabf
evil file with 'spaces".txt	d41d8cd98f00b204e9800998ecf8427e
sample_content.bin	a58d0995219075ca9df6446a6ea6480e
EOF
# ' for emacs
        } else {
	    ok(1);
	    #XXX really check time!
#  	    ok(join("", sort @output), <<'EOF');
#  empty_product.bin       1006428329
#  sample_content.bin      1006428682
#  empty_product_added.bin 1006428435
#  CVS/Root        1006428305
#  CVS/Repository  1006428305
#  CVS/Entries     1011099954
#  EOF
        }
    } else {
	skip("$method is not supported",1) for (1..5);
    }
}

my $homedir;
if (eval 'getpwnam("dummy")') {
    $homedir = (getpwnam("dummy"))[7];
}

CHECKEXIST: {
    if (!defined $homedir) {
	skip("dummy user is missing",1) for (1 .. $tests);
	exit(0);
    }

    if (!-d "$homedir/$stagingdir" ||
	!-d "$homedir/$cgidir") {
	warn "The directory $homedir/$stagingdir or $homedir/$cgidir does not exist\n";

	if (!$ENV{BATCH}) {
	    print STDERR "Do you want to create these directories (needs sudo permissions)? (y/N) ";
	    chomp(my $yn = <STDIN>);
	    if ($yn eq 'y') {
		foreach my $dir ("$homedir/$stagingdir",
				 "$homedir/$cgidir") {
		    system("sudo mkdir $dir");
		    system("sudo chmod 2775 $dir");
		    system("sudo chown dummy.oodevel $dir");
		}
		if (-d "$homedir/$stagingdir" &&
		    -d "$homedir/$cgidir") {
		    last CHECKEXIST;
		}
		warn "Problems occurred...\n";
	    }
	}

	skip("Some directories are missing",1) for (1 .. $tests);
	exit(0);
    }
}

do "$FindBin::RealBin/publish_common.pl"; warn $@ if $@;

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0
sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

__END__