#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 11_we_check_userdb.t,v 1.1 2003/06/29 19:11:32 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use WE::DB::ComplexUser;
use WE::DB::User;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 4 }

my $testdir = "$FindBin::RealBin/test";
my $userfile = "$testdir/pw.db";
my $complexuserfile = "$testdir/cpw-none.db";

my $u1 = WE::DB::ComplexUser->new(undef, $complexuserfile,
				  -connect => 1,
				  -readonly => 1,
				 );
my $u2 = WE::DB::ComplexUser->new(undef, $userfile,
				  -connect => 1,
				  -readonly => 1,
				 );
ok($u1->check_data_format, 1);
ok($u2->check_data_format, 0);

my $u3 = WE::DB::User->new(undef, $complexuserfile,
			   -connect => 1,
			   -readonly => 1,
			  );
my $u4 = WE::DB::User->new(undef, $userfile,
			   -connect => 1,
			   -readonly => 1,
			  );
ok($u3->check_data_format, 0);
ok($u4->check_data_format, 1);

__END__
