#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 99_stresstest.t,v 1.3 2004/06/05 10:35:54 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Getopt::Long;
use Data::Dumper;

use WE_Sample::Root;
use WE::Util::Support;

BEGIN {
    if (!eval q{
	use Test::More qw(no_plan);
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my $abort;

$SIG{INT} = sub { $abort = 1 };

my $root_class = "WE_Sample::Root";
my $testdir = "$FindBin::RealBin/test";
my $serializer = 'Data::Dumper';
my $connect = 0;
my $locking = 1;
my $check_consistency_frequency = 20;
my $check_fsck_frequency = 20;

my $fork = 3;
my $v = 0;

if (!GetOptions("fork|processes=i" => \$fork,
		"v" => \$v,
		"rootclass=s" => \$root_class,
		"testdir=s" => \$testdir,
		"serializer=s" => \$serializer,
		"connect!" => \$connect,
		"lock|locking!" => \$locking,
		"checkconsistencyfrequency" => \$check_consistency_frequency,
		"checkfsckfrequency" => \$check_fsck_frequency,
	       )) {
    die "usage!";
}

if (!$ENV{WE_FRAMEWORK_STRESSTEST}) {
 SKIP: {
	skip(<<EOF, 1);
Please set the environment variable WE_FRAMEWORK_STRESSTEST
if you really like to run this test. This test will add additional
documents and folders to the test database and will not abort unless
hitting CTRL-C.
EOF
    }
    exit 0;
}

my $r;
my $objdb;

if ($fork == 1) {
    process();
} else {
    for (1..$fork) {
	if (fork == 0) {
	    process();
	    exit 0;
	}
    }

    for (1..$fork) {
	last if wait == -1;
    }
}

sub process {
    $r = $root_class->new(-rootdir    => $testdir,
			  -serializer => $serializer,
			  -connect    => $connect,
			  -locking    => $locking,
			 );
    ok(ref $r, $root_class);
    ok($r->RootDir, $testdir);

    $objdb = $r->ObjDB;
    ok(ref $objdb, 'WE::DB::Obj');

    my @folders = all_folders();
    my @pages   = all_pages();

    my $counter = 0;
    my $fsck_counter = 0;

    while (!$abort) {
	my $random_folder = $folders[int rand(@folders)];
	my $new_page_id = create_page($random_folder);
	push @pages, $new_page_id;

	my $random_page = $pages[int rand(@pages)];
	edit_page($random_page);

	if (rand(100) < 20) { # create new folder in 20% of all iterations
	    my $new_folder_id = create_folder($random_folder);
	    push @folders, $new_folder_id;
	}

	if (rand(100) < 10) {
	    my $delete_page_id = $pages[int rand(@pages)];
	    delete_page($delete_page_id);
	    @pages = grep { $_ ne $delete_page_id } @pages;
	}

	# XXX Delete folder? But not the root folder...

	if ($fork == 1 && $counter >= $check_consistency_frequency) {
	    $counter = 0;

	    my %now_folders = map { ($_=>1) } all_folders();
	    my %now_pages   = map { ($_=>1) } all_pages();

	    my %folders = map {($_=>1)} @folders;
	    my %pages   = map {($_=>1)} @pages;

	    diag scalar(@folders) . " folders expected in database";
	    diag scalar(@pages) . " pages expected in database";

	    my $errors = 0;
	    for my $folder (@folders) {
		if (!exists $now_folders{$folder}) {
		    ok(0, "Folder $folder got lost");
		    $errors++;
		}
	    }
	    for my $page (@pages) {
		if (!exists $now_pages{$page}) {
		    ok(0, "Page $page got lost");
		    $errors++;
		}
	    }

	    for my $folder (keys %now_folders) {
		if (!exists $folders{$folder}) {
		    ok(0, "Unexpected new folder $folder");
		    $errors++;
		}
	    }
	    for my $page (keys %now_pages) {
		if (!exists $pages{$page}) {
		    ok(0, "Unexpected new page $page");
		    $errors++;
		}
	    }

	    is($errors, 0, "Consistency check");
	} else {
	    $counter++;
	}

	if ($fsck_counter >= $check_fsck_frequency) {
	    $fsck_counter = 0;

	    my $contentdb = $r->ContentDB;

	    my $errors = $objdb->check_integrity($contentdb);
	    my $has_errors = $errors->has_errors;
	    is($has_errors, 0, "Fsck check for object database")
		or diag Dumper($errors);

	    my $contentdb_errors = $contentdb->check_integrity($objdb);
	    my $has_contentdb_errors = $contentdb_errors->has_errors;
	    is($has_contentdb_errors, 0, "Fsck check for content database")
		or diag Dumper($contentdb_errors);

	} else {
	    $fsck_counter++;
	}

    }
}

sub create_page {
    my $parid = shift;
    my $obj = $objdb->insert_doc
	(-content => "This is random content. " x int(rand(100)),
	 -parent  => $parid,
	 -Title   => "Random title " . scalar(localtime),
	);
    ok($obj, "Created page with id " . $obj->Id);
    $obj->Id;
}

sub delete_page {
    my $objid = shift;
    $objdb->remove($objid);
    my $obj = $objdb->get($objid);
    ok(!$obj, "Deleted objected with id " . $objid);
}

sub create_folder {
    my $parid = shift;
    my $obj = $objdb->insert_folder
	(-parent => $parid,
	 -Title => "Random folder " . scalar(localtime),
	);
    ok($obj, "Created folder with id " . $obj->Id);
    $obj->Id;
}

sub edit_page {
    my $id = shift;
    my $obj = $objdb->get_object($id);
    if (!$obj) {
	if ($fork == 1) {
	    ok(0, "Cannot get object with id $id");
	} else {
	    diag("Cannot get object with id $id, maybe deleted by other process");
	}
    } else {
	$obj->Title("Changed title " . scalar(localtime));
	$objdb->replace_object($obj);
	$objdb->replace_content($obj, "Changed content. " x int(rand(100)));
	ok(1);
    }
}

sub all_folders {
    my @folders;
    $objdb->connect_if_necessary
	(sub {
	     $objdb->walk
		 ($objdb->root_object->Id, sub {
		      my($id) = @_;
		      my $obj = $objdb->get_object($id);
		      if (!$obj) {
			  ok(0, "Cannot get object for id $id");
		      }
		      if ($obj->is_folder &&
			  $obj->object_is_insertable("WE::Obj::Folder")) {
			  push @folders, $obj->Id;
		      }
		  });
	 });
    @folders;
}

sub all_pages {
    my @pages;
    $objdb->connect_if_necessary
	(sub {
	     $objdb->walk
		 ($objdb->root_object->Id, sub {
		      my($id) = @_;
		      my $obj = $objdb->get_object($id);
		      if (!$obj) {
			  ok(0, "Cannot get object for id $id");
		      }
		      if ($obj->is_doc) {
			  push @pages, $obj->Id;
		      }
		  });
	 });
    @pages;
}

__END__
