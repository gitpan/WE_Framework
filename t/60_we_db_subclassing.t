#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 60_we_db_subclassing.t,v 1.1 2005/01/28 08:40:19 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempdir);
	1;
    }) {
	print "1..0 # skip: no Test::More and/or File::Temp modules\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

use Getopt::Long;
my %opt;
GetOptions(\%opt, "debug!") or die "usage!";

{
    package WE_sample::Root;
    use base qw(WE_Singlesite::Root);

    WE::Obj->use_classes(':all');
    WE::DB->use_databases(qw/Obj ComplexUser Content OnlineUser/);

    sub new {
	my($class, %args) = @_;
	my $self = {};
	bless $self, $class;

	my $db_dir = delete $args{-rootdir};
	die "No db_dir given" if !defined $db_dir;
	$self->RootDir($db_dir);
	my $readonly = defined $args{-readonly} ? delete $args{-readonly} : 0;
	if (!$readonly) {
	    die "$db_dir is not writable" if !-w $db_dir;
	}
	my $locking = defined $args{-locking} ? delete $args{-locking} : 1;
	my $serializer = defined $args{-serializer} ? delete $args{-serializer} : "Data::Dumper";

	$self->ObjDB        (WE::DB::Obj->new($self, "$db_dir/objdb.db",
					      -serializer => $serializer,
					      -locking => $locking,
					      -readonly => $readonly,
					      -connect  => $args{-connect},
					      ($args{-db} ? (-db => $args{-db}) : ()),
					     ));
	$self->UserDB       (WE::DB::ComplexUser->new($self, "$db_dir/userdb.db",
						      -readonly => $readonly,
						      -connect  => $args{-connect},
						     ));
	$self->ContentDB    (WE::DB::Content->new($self, "$db_dir/content",
						  -readonly => $readonly));
	$self->OnlineUserDB (WE::DB::OnlineUser->new($self, "$db_dir/onlinedb.db",
						     -readonly => $readonly));
	$self->NameDB       (WE::DB::Name->new($self, "$db_dir/name.db",
					       -readonly => $readonly,
					       -connect  => $args{-connect},
					      ));
	$self;
    }
}

my $dbdir = tempdir(CLEANUP => !$opt{debug});
my $root;
eval {
    # Set -locking => 0, because it seems that no proper cleanup is done
    # if this "new" dies.
    $root = WE_sample::Root->new(-rootdir => $dbdir, -locking => 0);
};
like($@, qr/Can't locate object method "new" via package "WE::DB::Name"/,
     "Expected regression failure");

# do the preload now
WE::DB->use_databases(qw/Name/);
$root = WE_sample::Root->new(-rootdir => $dbdir);
isa_ok($root, "WE_sample::Root");
isa_ok($root, "WE::DB");

__END__
