#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 13_htpasswd.t,v 1.5 2005/12/12 12:28:16 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::DB::ComplexUser;
use WE::Util::Htpasswd;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # tests only work with installed Test module\n";
	exit;
    }
}

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

BEGIN {
    if (!eval { WE::Util::Htpasswd::htpasswd_exe() }) {
	print "1..0 # no htpasswd in the PATH of this system\n";
	exit;
    }
}

BEGIN { plan tests => 9 }

my $testdir = "$FindBin::RealBin/test";
my $htpasswd = "$testdir/.htpasswd";

{
    # check for non valid databases
    my $pwfile = "$testdir/cpw-crypt.db";
    my $u = WE::DB::ComplexUser->new(undef, $pwfile);
    eval {
	WE::Util::Htpasswd::create($htpasswd, $u);
    };
    ok($@ =~ /CryptMode/i, 1);
}

my $pwfile = "$testdir/cpw-none.db";
my $u = WE::DB::ComplexUser->new(undef, $pwfile);
unlink $htpasswd;
ok(!-e $htpasswd);
WE::Util::Htpasswd::create($htpasswd, $u);
ok(-e $htpasswd);
ok(-r $htpasswd);

my %users;
open(H, $htpasswd) or die $!;
while(<H>) {
    chomp;
    my($user,$passwd) = split /:/, $_, 2;
    $users{$user} = $passwd;
}
foreach my $user ("ole#maetzner", "ole#maetzner2", "ole", "gerhardschroeder") {
    ok(exists $users{$user});
}
ok(scalar keys %users, 5);


__END__
