#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 93_export.t,v 1.5 2003/11/27 00:02:35 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Path;
use File::Spec;
use File::Compare;
use File::Basename;
use DB_File;

use WE::DB;
use WE::Export;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # tests only work with installed Test module\n";
	exit;
    }
}

BEGIN { plan tests => 9 + 4*4 }

if (!File::Spec->can("rel2abs")) {
    eval 'sub File::Spec::rel2abs { shift; $_[0] }'; # XXX poor solution
}

my $class = "WE_Singlesite::Root";
my $rootdir = "$FindBin::RealBin/test";

my $test3dir = File::Spec->rel2abs("$FindBin::RealBin/test3");
rmtree([$test3dir], 0);

my $r = new WE::DB -class => $class,
                   -rootdir => $rootdir,
                   -readonly => 1,
                   -locking => 0;
ok($r->isa("WE::DB"), 1);

my $ex = new WE::Export $r;
ok($ex->isa("WE::Export"), 1);

ok(!defined $ex->Tmpdir, 1);

my $archfile = File::Spec->rel2abs("$FindBin::RealBin/export.tar.gz");
unlink $archfile;
$ex->Archive($archfile);
ok($ex->Archive, $archfile);

ok($ex->export_all);
ok(-e $archfile, 1);

ok($ex->import_archive($ex->Archive, $test3dir));

my $oldcontent = "$rootdir/content";
my $newcontent = "$test3dir/content";

my $ok = 1;
foreach my $f (glob("$newcontent/*")) {
    my $base = basename $f;
    $ok = 0 if (compare($f, "$oldcontent/$base") != 0);
}
ok($ok);

foreach my $base (qw(objdb userdb onlinedb name)) {
    print "# test db $base\n";
    my %olddb;
    my %newdb;

    ok(tie(%olddb, 'DB_File', "$rootdir/$base.db", O_RDONLY, 0644));
    ok(tie(%newdb, 'DB_File', "$test3dir/$base.db", O_RDONLY, 0644));

    $ok = 1;
    while(my($k,$v) = each %olddb) {
	$ok = 0 if ($v ne $newdb{$k});
    }
    ok($ok);
    ok(scalar keys %olddb, scalar keys %newdb);

    untie %olddb;
    untie %newdb;
}

my $delete_archfile = 1;

my @tar_contents = `tar tfz $archfile`;
my @ok_tar_contents = grep {
    /(^content|.*\.db\.dd$|^mtree$)/;
} @tar_contents;
ok(scalar @tar_contents, scalar @ok_tar_contents)
    or $delete_archfile = 0;

END {
    unlink $archfile if $delete_archfile && defined $archfile && -e $archfile;
}
__END__
