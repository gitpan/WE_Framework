#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use FindBin;

use WE::DB::ComplexUser;
use WE::Util::Htpasswd;
use WE::Util::Htgroup;

BEGIN {
    if (!eval q{
	use Test::More;
	use Term::ReadKey;
	1;
    }) {
	print "1..0 # skip: tests only work with installed Test::More and/or Term::ReadKey modules\n";
	exit;
    }
}

BEGIN { plan tests => 5 }

my $is_interactive = 0;
use Getopt::Long;
GetOptions("interactive" => \$is_interactive) or die "usage!";

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
is(-d $testdir, 1);
is(-w $testdir, 1);

my $pwfile = "$testdir/cpw-pop3.db";
unlink $pwfile;

my $u = WE::DB::ComplexUser->new(undef, $pwfile,
				 -connect => 1,
				 -invalidchars => WE::Util::Htpasswd::invalid_chars(),
				 -invalidgroupchars => WE::Util::Htgroup::invalid_chars(),
				 -crypt => 0,
				);

SKIP: {
    my $tests = 3;
    skip("Request interactive test with -interactive option", $tests) if !$is_interactive;

    my($user) = getpwuid($<);

    print STDERR "Your Unix password: ";
    ReadMode('noecho');
    my $pass = ReadLine(0);
    chomp $pass;
    ReadMode('normal');

    my $user_object = WE::UserObj->new;
    $user_object->Username("test1");
    $user_object->AuthType("Unix");
    $user_object->{Auth_Unix_User} = $user;
    isa_ok($user_object, "WE::UserObj");
    $u->add_user_object($user_object);
    is($u->user_exists("test1"), 1);
    is($u->identify("test1", $pass), 1);
}

