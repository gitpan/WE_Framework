#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 92_htaccess.t,v 1.3 2003/02/12 10:12:43 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::Util::Htaccess;
use WE_Sample::Root;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # tests only work with installed Test module\n";
	exit;
    }
}

BEGIN { plan tests => 12 }

my $testdir = "$FindBin::RealBin/test";
my $htaccess = "$testdir/.htaccess";
my $connect = 1;

my $r = new WE_Sample::Root -rootdir => $testdir,
                            -connect => $connect;
ok(ref $r, 'WE_Sample::Root');

unlink $htaccess;
ok(!-e $htaccess);
WE::Util::Htaccess::create($htaccess, $r->ObjDB,
			   -authname => "My Auth Realm",
			   -authuserfile => ".htpasswd",
			   -authgroupfile => ".htgroup",
			   -filter => sub {
			       # filter object with id 31
			       my($obj) = shift;
			       if ($obj->Id eq '31') {
				   return 0;
			       }
			       1;
			   },
			   -add => "ErrorDocument 401 /index.html",
			   (-r "$testdir/.htaccess.add" # may be missing
			    ? (-addfile => "$testdir/.htaccess.add")
			    : ()
			    ),
			   );
ok(-e $htaccess);

{
    local $/ = undef;
    open(F, $htaccess) and ok(1);
    my $buf = scalar <F>;
    close F;
    ok(length($buf)>0);
    ok($buf =~ /ErrorDocument 401/);
    if (!-r "$testdir/.htaccess.add") {
	skip(".htacess.add missing", 1);
    } else {
	ok($buf =~ /this should be added/);
    }
    ok($buf =~ /AuthName/);
    ok($buf =~ /AuthGroupFile \.htgroup/);
    ok($buf =~ /\.htaccess/);
}

{
    my $htaccess2 = "$testdir/.htaccess2";
    unlink $htaccess2;
    WE::Util::Htaccess::create
	    ($htaccess2, undef,
	     -authname => "My Auth Realm",
	     -authuserfile => ".htpasswd",
	     -authgroupfile => ".htgroup",
	     -restrict => "group member; user admin root",
	    );
    ok(-e $htaccess2);
    ok(-s $htaccess2);
}

__END__
