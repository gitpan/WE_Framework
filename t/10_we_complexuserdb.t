#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 10_we_complexuserdb.t,v 1.14 2005/02/16 22:46:09 eserte Exp $
# Author: Olaf Mätzner, Slaven Rezic
#

use strict;
use FindBin;

use Storable qw(dclone);

use WE::DB::ComplexUser;
use WE::Util::Htpasswd;
use WE::Util::Htgroup;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: tests only work with installed Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 2 + (43+7+22+3+8)*4 + 3*2 + 6 }

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
is(-d $testdir, 1);
is(-w $testdir, 1);

foreach my $connect (0, 1) {
    foreach my $crypt_mode ('crypt', 'none') {
	my $crypt_mode_arg = $crypt_mode eq 'crypt' ? undef : $crypt_mode;

	my $pwfile = "$testdir/cpw-$crypt_mode.db";
	unlink $pwfile;

	my $u = WE::DB::ComplexUser->new(undef, $pwfile,
					 -connect => $connect,
					 -invalidchars => WE::Util::Htpasswd::invalid_chars(),
					 -invalidgroupchars => WE::Util::Htgroup::invalid_chars(),
					 -crypt => $crypt_mode_arg);

	is($u->CryptMode, $crypt_mode);
	#3 neuer user angelegt
	is($u->add_user("gerhardschroeder","bla"), $u->ERROR_OK);
	# neuer user angelegt
	is($u->add_user("ole","bla","Olaf Mätzner"), $u->ERROR_OK);
	# user nicht angelegt, gibt es schon
	is($u->add_user("ole","bla"), $u->ERROR_USER_EXISTS);
	# user wird angelegt, Hash macht nichts
	is($u->add_user("ole#maetzner","bla"), $u->ERROR_OK);
	#7 entsprechende Fehlermeldung:
	is($u->error($u->add_user("ole#maetzner2","bla")),"ok");

	is($u->add_user("eserte","bla"), $u->ERROR_OK);

	{
	    my $uo = $u->get_user_object("gerhardschroeder");
	    if ($crypt_mode eq 'crypt') {
		isnt($uo->Password, "bla", "Password is encrypted");
	    } elsif ($crypt_mode eq 'none') {
		is($uo->Password, "bla", "Password is clear text");
	    } else {
		pass("Unknown crypt mode");
	    }
	}

	{
	    my $user_object = WE::UserObj->new;
	    isa_ok($user_object, "WE::UserObj");
	    eval {
		$u->add_user_object($user_object);
	    };
	    like($@, qr/empty/);
	    $user_object->{Username} = "gerhardschroeder";
	    is($user_object->name, "gerhardschroeder");
	    is($u->add_user_object($user_object), $u->ERROR_USER_EXISTS);
	    $user_object->Username("angelamerkel");
	    $user_object->Realname("Angela Merkel");
	    $user_object->Password("geheim");
	    $user_object->Groups(["cdu"]);
	    is($u->add_user_object($user_object), $u->ERROR_OK);
	    is($u->user_exists("angelamerkel"), 1);

	    {
		my $uo = $u->get_user_object("angelamerkel");
		if ($crypt_mode eq 'crypt') {
		    isnt($uo->Password, "geheim", "Password is encrypted");
		} elsif ($crypt_mode eq 'none') {
		    is($uo->Password, "geheim", "Password is clear text");
		} else {
		    pass("Unknown crypt mode");
		}
	    }

	    is($u->delete_user("angelamerkel"), 1);
	    is($u->user_exists("angelamerkel"), 0);
	}

	is($u->get_fullname("ole"),"Olaf Mätzner");
	is($u->get_fullname("gerhardschroeder"),"new user");
	is($u->get_fullname("xoxle"),0);

	#11 falsches password
	is($u->identify("ole","blubber"), $u->ERROR_NOT_ACCEPTED);
	# richtiges password
	is($u->identify("ole","bla"), $u->ERROR_OK);

    SKIP: {
	    skip("for crypt_mode $crypt_mode", 1)
		unless $crypt_mode eq "none";
	    is($u->get_user_object("ole")->Password, "bla");
	}

	#13 user existiert
	is($u->user_exists("gerhardschroeder"),1);
	# user existiert nicht
	is($u->user_exists("xoxlxe"),0);

	#15 user nicht gelöscht - den gibts gar nicht.
	is($u->delete_user("willy"),0);
	# user gelöscht
	is($u->delete_user("gerhardschroeder"),1);
	is($u->user_exists("gerhardschroeder"),0);

	#18 user einer gruppe zuordnen
	is($u->add_group("ole","admins"),1);
	is($u->add_group("eserte","admins"),1);
	is($u->add_group("ole","admins"),0); # schon drin
	is($u->add_group("ole","doofies"),1);

	#21 in welchen Gruppen ist der user?
	is(join("#",$u->get_groups("ole")) ,"admins#doofies");
	# user ist nicht in dieser Gruppe
	is($u->is_in_group("ole","putzfrauen"),0);
	# user ist in dieser Gruppe
	is($u->is_in_group("ole","admins"),1);

	#24 Gruppe löschen
	is($u->delete_group("ole","admins"),1);
	# in welchen Gruppen ist der user?
	is(join("#",$u->get_groups("ole")) ,"doofies");

	$u->add_user("gerhardschroeder","bla");
	$u->add_group("gerhardschroeder","admins");
	#$u->add_group("gerhardschroeder","kanzlers");
	#warn join(":",$u->get_users_of_group("admins"));
	#warn join(":",$u->get_all_groups());

	my %all_users = map { ($_=>1) } $u->get_all_users;
	foreach my $user ("ole#maetzner", "ole#maetzner2", "ole", "gerhardschroeder") {
	    ok($all_users{$user});
	}
	is(scalar keys %all_users, 5)
	    or diag "Got: " . join(", ", keys %all_users);

	############################################################
	$u->ErrorType($u->ERROR_TYPE_DIE);
	$@ = "";
	eval {
	    $u->add_user("_invalid", "bla");
	};
	like($@, qr/not allowed/, "_ with die");

	$u->ErrorType($u->ERROR_TYPE_RETURN);
	is($u->add_user("_invalid", "bla"), $u->ERROR_INVALID_CHAR);
	like($u->ErrorMsg, qr/starting.*not allowed/, "_ with return");

	############################################################
	$u->ErrorType($u->ERROR_TYPE_DIE);
	$@ = "";
	eval {
	    $u->add_user("inva:lid", "bla");
	};
	like($@ , qr/invalid char/i, "Invalid char with die");

	$u->ErrorType($u->ERROR_TYPE_RETURN);
	is($u->add_user("inva:lid", "bla"), $u->ERROR_INVALID_CHAR);
	like($u->ErrorMsg, qr/invalid char/i, "Invalid char with return");

	############################################################
	$u->ErrorType($u->ERROR_TYPE_DIE);
	$@ = "";
	eval {
	    $u->add_group("gerhardschroeder", "inva:lid");
	};
	like($@, qr/invalid char/i, "Invalid group char with die");

	$u->ErrorType($u->ERROR_TYPE_RETURN);
	is($u->add_group("gerhardschroeder", "inva:lid"), $u->ERROR_INVALID_CHAR);
	like($u->ErrorMsg, qr/invalid char/i, "Invalid group char with return");

	$u->ErrorType($u->ERROR_TYPE_DIE);

	my $userobj = $u->get_user_object("gerhardschroeder");
	$userobj->{Stellung} = "Kanzler";
	is(!!$u->set_user_object($userobj->Username, $userobj), 1);
	is(!!$u->set_user_object($userobj), 1);

	my $old_userobj = $u->get_user("gerhardschroeder");
	is(join("#",@{$old_userobj->{groups}}), "admins");
	is($old_userobj->{username},"gerhardschroeder");
	is($old_userobj->{password},$userobj->Password);
	is($old_userobj->{fullname},$userobj->Realname);
	is($old_userobj->{Stellung},$userobj->{Stellung});

	my $userobj_fetched = $u->get_user_object("gerhardschroeder");
	is($userobj->{Stellung}, "Kanzler");
	delete $userobj->{Stellung};
	$u->set_user_object($userobj->Username, $userobj);

	my $userobj_fetched2 = $u->get_user_object("gerhardschroeder");
	ok(!exists $userobj->{Stellung});

	my $cloned_userobj = dclone $userobj;
	$u->set_password($cloned_userobj, "new_password");
	if ($u->CryptMode ne "crypt") {
	    is($cloned_userobj->Password, "new_password", "set_password, crypted mode");
	} else {
	    is($cloned_userobj->Password, $u->_encrypt("new_password"), "set_password, plain mode");
	}

	my @groups = ("spd", "niedersachsen", "admins");
	is($u->set_groups("gerhardschroeder", @groups), 1);
	my $userobj_fetched3 = $u->get_user_object("gerhardschroeder");
	is(join("#", $u->get_groups("gerhardschroeder")),
	   join("#", @groups));

	# Group tests
	{
	    my $same_groups = sub {
		my($g1, $g2) = @_;
		my %g1 = map {($_,1)} @$g1;
		my %g2 = map {($_,1)} @$g2;
		join("#", sort keys %g1) eq
		    join("#", sort keys %g2);
	    };
	    
	    ok($same_groups->([ $u->get_all_groups ],
			      [ $u->_predefined_groups ]));
	    $u->delete_group_definition("spd"); # this is only available in user defs
	    ok($same_groups->([ $u->get_all_groups ],
			      [ $u->_predefined_groups ]));
	    ok(!grep { $_ eq "spd" } $u->get_groups("gerhardschroeder"));
	    $u->delete_all_groups;
	    is(join("#",$u->get_all_groups), "");

	    my $group_obj = WE::GroupObj->new;
	    isa_ok($group_obj, "WE::GroupObj");
	    eval {
		$u->add_group_definition($group_obj);
	    };
	    like($@, qr/empty/);
	    $group_obj->Groupname("testgroup");
	    is($group_obj->name, "testgroup");
	    $group_obj->Description("Das ist eine Testgruppe");
	    is($u->add_group_definition($group_obj),
	       WE::DB::ComplexUser::ERROR_OK);
	    my $res = $u->add_group_definition("testgroup");
	    is($res, WE::DB::ComplexUser::ERROR_GROUP_EXISTS);
	    like($u->error($res), qr/group already exists/);
	    is(join("#", $u->get_all_groups), "testgroup");

	    my $group = $u->get_group_definition("testgroup");
	    isa_ok($group, "WE::GroupObj");
	    is($group->Groupname, "testgroup");
	    is($group->Description, "Das ist eine Testgruppe");

	    $group->{Description} = "Heisst jetzt anders";
	    $u->set_group_definition("testgroup", $group);
	    $group = $u->get_group_definition("testgroup");
	    is($group->{Description}, "Heisst jetzt anders");
	    $group->Description("Changed again");
	    $u->set_group_definition($group);
	    $group = $u->get_group_definition("testgroup");
	    is($group->{Description}, "Changed again");

	    $u->add_group("gerhardschroeder", "testgroup");
	    ok(grep { $_ eq 'testgroup'} $u->get_groups("gerhardschroeder"));

	    $group = $u->get_group_definition("non-existing");
	    is($group, undef);

	    $u->delete_group_definition("testgroup");
	    $group = $u->get_group_definition("testgroup");
	    is($group, undef);
	    ok(!grep { $_ eq 'testgroup'} $u->get_groups("gerhardschroeder"));
	    
	}
    }
}

# re-open databases readonly
foreach my $crypt_mode ('crypt', 'none') {
    my $crypt_mode_arg = $crypt_mode eq 'crypt' ? undef : $crypt_mode;
    my $pwfile = "$testdir/cpw-$crypt_mode.db";
    my $u = WE::DB::ComplexUser->new(undef, $pwfile, -readonly => 1);
    ok($u->isa("WE::DB::ComplexUser"));
    is($u->CryptMode, $crypt_mode);
    is($u->identify("ole","bla"),1);
}

# concurrent access
{
    my $pwfile = "$testdir/cpw-concurrent.db";
    unlink $pwfile;
    my $u1 = WE::DB::ComplexUser->new(undef, $pwfile, -connect => 0);
    my $u2 = WE::DB::ComplexUser->new(undef, $pwfile, -connect => 0);
    is($u1->add_user("neilyoung","bla"), $u1->ERROR_OK);
    is($u1->user_exists("neilyoung"),1);
    is($u2->user_exists("neilyoung"),1);
    is($u2->delete_user("neilyoung"),1);
    is($u2->user_exists("neilyoung"),0);
    is($u1->user_exists("neilyoung"),0);
    unlink $pwfile;
}

__END__
