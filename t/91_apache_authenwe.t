#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

my $testdir;

BEGIN {
    $testdir = "$FindBin::RealBin/test";
    if (!eval q{
	use Test::More;
	use Apache::FakeRequest;
	use Apache::AuthenWE;
 	die if ! -d $testdir;
	1;
    }) {
	print "1..0 # skip: tests only work with installed Test::More and Apache::FakeRequest modules and existing $testdir directory\n";
	exit;
    }
}

BEGIN { plan tests => 7 }

my $user = "motu";
my $password = "utom";

{
    package Apache::MyFakeRequest;
    use base qw(Apache::FakeRequest);
    sub get_basic_auth_pw {
	my $self = shift;
	my $res = $self->{"get_basic_auth_pw"};
	ref $res ? @$res : $res;
    }

    package Apache::FakeConnection;
    use base qw(Class::Accessor);
    __PACKAGE__->mk_accessors(qw(user));

    package Apache::FakeDirConfig;
    sub get { shift->{shift()} }
}

my $r = Apache::MyFakeRequest->new;
my $connection = bless {}, 'Apache::FakeConnection';
$connection->user("non-existent user");
$r->connection($connection);

my $dir_config;

$dir_config = bless { }, 'Apache::FakeDirConfig';
$r->dir_config($dir_config);
is(Apache::AuthenWE::handler($r), 401, "No dir configuration")
    or diag $r->log_reason;

$dir_config = bless { WE_RootClass => "WE_Sample::Root",
		      WE_RootDir   => $testdir,
		      WE_Authen_LogoutUser => "logoutuser",
		    }, 'Apache::FakeDirConfig';
$r->dir_config($dir_config);

is(Apache::AuthenWE::handler($r), 401, "Login failed")
    or diag $r->log_reason;

$r->connection->user($user);
$r->{"get_basic_auth_pw"} = [0, $password];
$r->requires([{requirement => "valid-user"}]);
is(Apache::AuthenWE::handler($r), 0, "Login success")
    or diag $r->log_reason;

$r->requires([{requirement => "user foo bar bla"}]);
is(Apache::AuthenWE::handler($r), 401, "User not in require user list")
    or diag $r->log_reason;

$r->requires([{requirement => "group admin"}]);
is(Apache::AuthenWE::handler($r), 401, "User in admin group")
    or diag $r->log_reason;

$r->requires([{requirement => "group foo bar bla"}]);
is(Apache::AuthenWE::handler($r), 401, "User not in require group list")
    or diag $r->log_reason;

$r->connection->user("logoutuser");
is(Apache::AuthenWE::handler($r), 0, "logoutuser always succeeds")
    or diag $r->log_reason;

__END__
