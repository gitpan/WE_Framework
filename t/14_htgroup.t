#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 14_htgroup.t,v 1.2 2004/12/03 15:51:15 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::DB::ComplexUser;
use WE::Util::Htgroup;

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

BEGIN { plan tests => 5 }

my $testdir = "$FindBin::RealBin/test";
my $htgroup = "$testdir/.htgroup";

my $pwfile = "$testdir/cpw-none.db";
my $u = WE::DB::ComplexUser->new(undef, $pwfile);
unlink $htgroup;
ok(!-e $htgroup);
WE::Util::Htgroup::create($htgroup, $u);
ok(-e $htgroup);
ok(-r $htgroup);

my %groups;
open(H, $htgroup) or die $!;
while(<H>) {
    chomp;
    my($group,$users) = split /:\s*/, $_, 2;
    $groups{$group} = [ split /\s+/, $users ];
}
ok(join(";", sort @{ $groups{'doofies'} }), 'ole');
ok(join(";", sort @{ $groups{'admins'} }), 'eserte;gerhardschroeder');

__END__
