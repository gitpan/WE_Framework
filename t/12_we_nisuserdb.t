#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 12_we_nisuserdb.t,v 1.1.1.1 2002/08/06 18:34:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test;
	use WE::DB::NISUser;
	use Net::Domain qw(hostdomain);
        die "Local test only" if (hostdomain ne 'intra.onlineoffice.de');
	1;
    }) {
	print "# tests only work with installed Test and Net::NIS modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 12 }

my $u = WE::DB::NISUser->new(undef);

ok($u->get_fullname("ole"),"Olaf Mätzner");
ok($u->get_fullname("eserte"),"Slaven Rezic");
ok($u->get_fullname("xoxle"),0);

ok($u->identify("dummy","xyz"),0);
ok($u->identify("dummy","dummy"),1);

ok($u->user_exists("eserte"),1);
ok($u->user_exists("xoxlxe"),0);

ok(grep { $_ eq 'alloo' } $u->get_groups("ole"), 1);
ok(grep { $_ eq 'oo' } $u->get_groups("ole"), 1);
ok(scalar(grep { $_ eq 'gibtsnich' } $u->get_groups("ole")), 0);
ok($u->is_in_group("ole","putzfrauen"),0);
ok($u->is_in_group("ole","oo"),1);

__END__
