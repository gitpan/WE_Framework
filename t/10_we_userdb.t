#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 10_we_userdb.t,v 1.2 2003/02/12 10:12:43 eserte Exp $
# Author: Olaf Mätzner
#

use strict;
use FindBin;

use WE::DB::User;

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

BEGIN { plan tests => 43 }

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

my $pwfile = "$testdir/pw.db";

unlink $pwfile;

my $u = WE::DB::User->new(undef, $pwfile);

 #3 neuer user angelegt
ok($u->add_user("gerhardschroeder","bla"),1);
 # neuer user angelegt
ok($u->add_user("ole","bla","Olaf Mätzner","userdef1","userdef2"),1);
my $uh = $u->get_user("ole");
ok(UNIVERSAL::isa($u, "HASH"));
ok($uh->{username}, "ole");
ok($uh->{fullname}, "Olaf Mätzner");
ok("@{$uh->{groups}}","");
ok(join("#",@{$uh->{userdef}}),"userdef1#userdef2");
 # user nicht angelegt, gibt es schon
ok($u->add_user("ole","bla"),0);
 # user nicht angelegt, Doppelpunkt enthalten
ok($u->add_user("ole:maetzner","bla"),0);
 #7 entsprechende Fehlermeldung:
#ok($u->error($u->add_user("ole:maetzner","bla")),"invalid character");
ok($WE::DB::User::ERROR, "Invalid character in user name");

ok($u->get_fullname("ole"),"Olaf Mätzner");
ok($u->get_fullname("gerhardschroeder"),"new user");
ok($u->get_fullname("xoxle"),0);

 #11 falsches password
ok($u->identify("ole","blubber"),0);
 # richtiges password
ok($u->identify("ole","bla"),1);

 #13 user existiert
ok($u->user_exists("gerhardschroeder"),1);
 # user existiert nicht
ok($u->user_exists("xoxlxe"),0);

 #15 user nicht gelöscht - den gibts gar nicht.
ok($u->delete_user("willy"),0);
 # user gelöscht
ok($u->delete_user("gerhardschroeder"),1);
ok($u->user_exists("gerhardschroeder"),0);

 #18 user einer gruppe zuordnen
ok($u->add_group("ole","admins"),1);
ok($u->add_group("ole","admins"),1);# schon drin, trotzdem 1 zurück geben
ok($u->add_group("ole","doofies"),1);

 #21 in welchen Gruppen ist der user?
ok(join("#",$u->get_groups("ole")) ,"admins#doofies");
 # user ist nicht in dieser Gruppe
ok($u->is_in_group("ole","putzfrauen"),0);
 # user ist in dieser Gruppe
ok($u->is_in_group("ole","admins"),1);

 #24 Gruppe löschen
ok($u->delete_group("ole","admins"),1);
 # in welchen Gruppen ist der user?
ok(join("#",$u->get_groups("ole")) ,"doofies");

$u->add_user("gerhardschroeder","bla");
$u->add_group("gerhardschroeder","admins");
#$u->add_group("gerhardschroeder","kanzlers");
#warn join(":",$u->get_users_of_group("admins"));
#warn join(":",$u->get_all_groups());

ok($u->get_user_field("ole",0), "userdef1");
ok($u->get_user_field("ole",1), "userdef2");
ok($u->get_user_field("ole",2), undef);
ok($u->set_user_field("ole",0,"newuserdef1"),1);
ok($u->get_user_field("ole",0,"newuserdef1"));
ok($u->set_user_field("ole",1,"newuserdef2"),1);
ok($u->get_user_field("ole",1,"newuserdef2"));
ok($u->set_user_field("ole",2,"newuserdef3"),1);
ok($u->get_user_field("ole",2,"newuserdef3"));
ok($u->set_user_field("ole",1,""),1);
ok($u->get_user_field("ole",1),"");
ok($u->set_user_field("ole",2,""),1);
ok($u->get_user_field("ole",2),"");
#ok($u->set_user_field("ole",2,"newuserdef3"),1);
#ok($u->get_user_field("ole",2,"newuserdef3"));

__END__
