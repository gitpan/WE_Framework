#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 80_locking.t,v 1.4 2004/06/07 06:58:55 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests $VERBOSE);

use FindBin;

use WE_Sample::Root;

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

    $tests = 5+20+1;
    $VERBOSE = 0;
}

BEGIN { plan tests => $tests }

if ($^O eq 'MSWin32') {
    print "# No fork --- no test\n";
    skip(1,1) for (1..$tests);
    exit;
}

sub microsleep {
    select(undef,undef,undef,$_[0]);
}

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

# incompatibility between *DB*File implementations and versions
unlink "$testdir/objdb.db";
unlink "$testdir/userdb.db";

{
    my $r = new WE_Sample::Root -rootdir => $testdir, -connect => "never";
    $r->delete_db;
}

my $ok;

if (fork == 0) {
    my $r = new WE_Sample::Root -rootdir => $testdir;
    ok(ref $r, 'WE_Sample::Root');
    microsleep 0.5;
    ok(ref $r, 'WE_Sample::Root');
    microsleep 0.5;
    undef $r;
    exit 0;
} else {
    microsleep 0.5; # make sure that this is called after the first fork
    my $r = new WE_Sample::Root -rootdir => $testdir;
    if (ref $r eq 'WE_Sample::Root') {
	$ok = 5;
	print "ok " . ($ok++) . "\n";
    }
    $r->ObjDB(undef);
    undef $r;
}

for (1..20) {
    if (fork == 0) {
	microsleep rand(1)*0.3;
	my $r = new WE_Sample::Root -rootdir => $testdir;
	print STDERR "Process $$ locks db ... " if $VERBOSE;
	microsleep rand(1)*0.3;
	undef $r;
	warn "and process $$ unlocks db\n" if $VERBOSE;
	exit 0;
    }
}

while ((my $pid = wait) != -1) {
    print "ok " . ($ok++) . "\n";
}

__END__
