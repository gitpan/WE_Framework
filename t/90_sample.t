#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 90_sample.t,v 1.22 2004/10/06 09:12:56 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Path;

use WE_Sample::Root;
use WE::Util::Support;
use WE::Util::LangString qw(new_langstring);
use WE::Util::Date;

my @root_classes;

if (eval {
    require GDBM_File;

    package WE_Sample::Root_GDBM;
    use base qw(WE_Singlesite::Root_GDBM);
    # mixin XXX these should go to WE_Root or so...

    *is_allowed            = *is_allowed;
    *get_released_children = *get_released_children;
    *get_released_object   = *get_released_object;

    *is_allowed            = \&WE_Sample::Root::is_allowed;
    *get_released_children = \&WE_Sample::Root::get_released_children;
    *get_released_object   = \&WE_Sample::Root::get_released_object;

    1;
}) {
    push @root_classes, qw(WE_Sample::Root_GDBM);
}

if (eval {
    require Tie::TextDir;

    package WE_Sample::Root_TieTextDir;
    use base qw(WE_Singlesite::Root_TieTextDir);
    # mixin XXX these should go to WE_Root or so...

    *is_allowed            = *is_allowed;
    *get_released_children = *get_released_children;
    *get_released_object   = *get_released_object;

    *is_allowed            = \&WE_Sample::Root::is_allowed;
    *get_released_children = \&WE_Sample::Root::get_released_children;
    *get_released_object   = \&WE_Sample::Root::get_released_object;

    1;
}) {
    push @root_classes, qw(WE_Sample::Root_TieTextDir);
}

# WE_Sample::Root should be last in list!
push @root_classes, qw(WE_Sample::Root);

my @serializer_classes = (undef, 'Storable', 'Data::Dumper');

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

eval 'require Time::HiRes';

my $init_test_count   = 4;
my $basic_test_count = 341;

plan tests => $init_test_count +
              $basic_test_count * 3 * scalar(@serializer_classes) * scalar(@root_classes);

if ($Test::VERSION <= 1.122) {
    $^W = 0; # too many warnings
}

my %bench;

my $testdir = "$FindBin::RealBin/test";
my $test2dir = "$FindBin::RealBin/test2";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

mkdir $test2dir, 0770;
ok(-d $test2dir, 1);
ok(-w $test2dir, 1);

ROOT_CLASS: for my $root_class (@root_classes) {

print "# root class: @{[out($root_class)]}\n";

SERIALIZER: for my $serializer (@serializer_classes) {

if ($serializer eq 'Storable' && !eval { require XXXStorable; 1 }) {
    skip("Storable not available", 1) for (1 .. $basic_test_count * 3);
    next SERIALIZER;
}

print "# serializer: @{[out($serializer)]}\n";

# various incompatibilities:
# * between Storable and Data::Dumper
# * between *DB*File implementations
# * between berkeley db versions
# XXX Better use the delete_db method!
unlink "$testdir/objdb.db";
rmtree "$testdir/objdb.dir", 0, 1;
unlink "$testdir/userdb.db";
unlink "$testdir/onlinedb.db";
unlink "$testdir/name.db";
unlink "$test2dir/userdb.db";

for my $connect (undef, 0, 1) {

print "# connect: @{[out($connect)]}\n";

my $t0;
if (defined &Time::HiRes::gettimeofday) {
    $t0 = [Time::HiRes::gettimeofday()];
}

{
    # Make sure the "motu" user exists
    my $u = WE::DB::User->new(undef, "$testdir/userdb.db");
    $u->add_user("motu","utom") if !$u->user_exists("motu");
}

{
    # Make sure that database files in $test2dir are deleted. There
    # may be problems if there are left-over db files from an
    # incompatible Berkeley DB version. The files in $testdir are
    # already cleaned up in t/80_locking.t
    my $r = $root_class->new(-rootdir => $test2dir, -connect => "never");
    $r->delete_db;
}

my $r2 = new WE::DB -class => $root_class,
                    -rootdir => $testdir,
		    -serializer => $serializer,
		    -connect => $connect;
ok(ref $r2, $root_class);
$r2->ObjDB(undef); # to prevent deadlocks --- but a simple "undef $r2" should be enough!!! XXX
ok($r2->ObjDB, undef);
undef $r2; # XXX

my $r = $root_class->new(-rootdir => $testdir,
			 -serializer => $serializer,
			 -connect => $connect);
ok(ref $r, $root_class);
ok($r->RootDir, $testdir);

$r->init;

my $objdb = $r->{ObjDB};
ok(ref $objdb, 'WE::DB::Obj');

ok($r->is_allowed("bla", 0), 0); # no user

# set the user by hand ... normally it would be done with $t->identify
$r->CurrentUser("eserte");
ok($r->CurrentUser, "eserte");
$r->CurrentLang("de");
ok($r->CurrentLang, "de");

$objdb->delete_db_contents;
ok(ref $objdb, 'WE::DB::Obj');

$r->ContentDB->delete_db_contents;

my $root_obj = $objdb->root_object;
ok($root_obj->isa('WE::Obj::FolderObj'), 1);
ok($root_obj->is_folder, 1);
ok($objdb->is_root_object($root_obj));
ok($objdb->is_root_object($root_obj->Id));

ok($r->is_allowed("release", $root_obj->Id), 0);

{
    # objectify/idify
    my $id = $root_obj;
    $objdb->objectify_params($id);
    ok($id->Id, $root_obj->Id);
    $objdb->idify_params($id);
    ok($id, $root_obj->Id);
}

my @folder;
foreach (1..6) {
    push @folder, $objdb->insert_folder(-title => "Titel Menü $_",
					-parent => $root_obj->Id);
    my $f = $folder[-1];
    my $fid = $f->Id;
    ok($fid != 0, 1);
    ok($f->Title, "Titel Menü $_");
    ok($f->Basename, undef);
    ok($f->isa('WE::Obj::FolderObj'), 1);
    ok($f->is_folder, 1);

    # parents with id
    my @parents = $objdb->parent_ids($fid);
    ok(scalar @parents, 1, "While testing number of parents for $_");
    ok($parents[0], $root_obj->Id);

    # parents with object
    @parents = $objdb->parent_ids($f);
    ok(scalar @parents, 1, "While testing number of parents for $_");
    ok($parents[0], $root_obj->Id);

    # parent method
    ok(($objdb->parents($f))[0]->Id, $root_obj->Id);

    my @children = $objdb->children_ids($fid);
    ok(scalar @children, 0, "While testing number of children for $_");
}

ok(scalar $objdb->children_ids($root_obj->Id), 6);
ok(scalar $objdb->children_ids($root_obj), 6);

ok(scalar $objdb->children($root_obj->Id), 6);
ok(scalar $objdb->children($root_obj), 6);

my $lang_string = new WE::Util::LangString
    en => "English title",
    de => "Deutscher Titel",
    ;

my $f2_id = $folder[2]->Id; # Note: this is "Titel Menü 3"
ok(scalar $objdb->children_ids($f2_id), 0);
my $orig_content = "Das hier ist der Content!";
my $doc = $objdb->insert_doc(-title => $lang_string,
			     -parent => $f2_id,
			     -content => $orig_content,
			     -WWWAuth => "group=auth,eserte,ole",
			    );
ok($doc->isa('WE::Obj::DocObj'), 1);
ok($doc->is_doc, 1);
my $docid = $doc->Id;
ok($docid != 0, 1);
ok($doc->Title->get("en"), "English title");
ok($doc->Title->get("de"), "Deutscher Titel");
ok($doc->Title->get("fallback"), "English title");

my $content = $objdb->content($docid);
ok($content, $orig_content);

eval {
    # No content for folder objects
    $objdb->content($f2_id);
};
ok($@ ne "", 1);

ok(scalar $objdb->children_ids($f2_id), 1);
$objdb->remove($docid);
ok($objdb->get_object($docid), undef);
ok(scalar $objdb->children_ids($f2_id), 0);

my $doc2 = $objdb->insert_doc(-title => "Doc2",
			      -parent => $f2_id,
			      -content => $orig_content,
			      -WWWAuth => "group=auth,user=ole",
			     );
my $doc2_id = $doc2->Id;
ok($doc2_id != 0, 1);
ok($doc2->isa('WE::Obj::DocObj'), 1);
ok($doc2->is_doc, 1);
ok(scalar $objdb->children_ids($f2_id), 1);

# Test change of attributes
$doc2->{NewAttribute} = "Just a value";
$objdb->replace_object($doc2);
$doc2 = $objdb->get_object($doc2_id);
ok($doc2->{NewAttribute}, "Just a value");
delete $doc2->{NewAttribute};
$objdb->replace_object($doc2);
$doc2 = $objdb->get_object($doc2_id);
ok(!exists $doc2->{NewAttribute}, 1);
$doc2->Title("New title");
$objdb->replace_object($doc2);
$doc2 = $objdb->get_object($doc2_id);
ok($doc2->Title, "New title");

my $content2 = "New content";
$objdb->replace_content($doc2_id, $content2);
ok($objdb->content($doc2_id), $content2);
# direct content access
my $contentdb = $r->ContentDB;
ok($contentdb->isa("WE::DB::Content"), 1);
ok($contentdb->get_content($doc2_id), $content2);
{
    my $filename = $contentdb->filename($doc2_id);
    ok(open(F, $filename), 1);
    local $/ = undef;
    ok(scalar <F>, $content2);
    close F;
}
ok($contentdb->get_content($doc2), $content2);
$objdb->replace_content_from_file($doc2_id, "$FindBin::RealBin/$FindBin::RealScript");
ok(length $objdb->content($doc2_id) > 0, 1);

# Test remove
ok(scalar $objdb->children_ids($root_obj->Id), 6);
{
    # check also Name removal
    my $f2_obj = $objdb->get_object($f2_id);
    $f2_obj->Name("will_be_removed");
    $objdb->replace_object($f2_obj);
    my $new_f2_obj = $objdb->get_object($f2_id);
    ok($new_f2_obj->Id, $f2_id);
    ok($new_f2_obj->Name, "will_be_removed");
}
$objdb->remove($f2_id);
ok(scalar $objdb->children_ids($root_obj->Id), 5);
ok($objdb->get_object($f2_id), undef);
ok($objdb->get_object($doc2_id), undef);

# Test link/unlink
my $f3_id = $folder[3]->Id;
my $doc3 = $objdb->insert_doc(-title => "Multilink doc",
			      -parent => $f3_id,
			      -content => "Ein bisschen content",
			      -WWWAuth => "user=eserte",
			     );
my $doc3_id = $doc3->Id;
ok($doc3_id != 0, 1);
ok($doc3->isa('WE::Obj::DocObj'), 1);
ok($doc3->is_doc, 1);
ok(scalar $objdb->children_ids($f3_id), 1);
ok(scalar $objdb->parent_ids($doc3_id), 1);

my $f4_id = $folder[4]->Id;
$objdb->link($doc3_id, $f4_id);
ok(scalar $objdb->parent_ids($doc3_id), 2);
ok(scalar $objdb->children_ids($f3_id), 1);
ok(scalar $objdb->children_ids($f4_id), 1);

my %doc3_parents = map { ($_ => 1) } $objdb->parent_ids($doc3_id);
ok(exists $doc3_parents{$f3_id}, 1);
ok(exists $doc3_parents{$f4_id}, 1);

$objdb->unlink($doc3_id, $f4_id);
ok(scalar $objdb->parent_ids($doc3_id), 1);
ok(scalar $objdb->children_ids($f3_id), 1);
ok(scalar $objdb->children_ids($f4_id), 0);

%doc3_parents = map { ($_ => 1) } $objdb->parent_ids($doc3_id);
ok(exists $doc3_parents{$f3_id}, 1);
ok(!exists $doc3_parents{$f4_id}, 1);

$objdb->unlink($doc3_id, $f3_id);
ok(!$objdb->exists($doc3_id), 1);
ok(scalar $objdb->children_ids($f3_id), 0);
ok(scalar $objdb->children_ids($f4_id), 0);

# link/unlink with objects instead of ids
$doc3 = $objdb->insert_doc(-parent => $folder[3],
			   -content => "Noch mehr doc3",
			   -title => "Ein Titel",
			   -WWWAuth => "group=auth,user=ole",
			  );
ok($doc3->is_doc, 1);
$objdb->link($doc3, $folder[4]);
ok(scalar $objdb->children_ids($folder[4]), 1);
$objdb->unlink($doc3, $folder[4]);
ok(scalar $objdb->children_ids($folder[4]), 0);

# check move
my $doc4;
{
    ok(scalar $objdb->children_ids($f3_id), 1);
    $doc4 = $objdb->insert_doc
	(-parent => $folder[3],
	 -content => "Ein Dokument zum Verschieben",
	 -title => WE::Util::LangString->new(en => "Move test",
					     de => "Test bewegen"),
	);
    ok($doc4->is_doc, 1);
    ok(scalar $objdb->children_ids($f3_id), 2);
    $objdb->move($doc4, undef, -destination => $f4_id);
    ok(scalar $objdb->children_ids($f3_id), 1);
    ok(scalar $objdb->children_ids($f4_id), 1);
    my(@parent_ids) = $objdb->parent_ids($doc4);
    ok(scalar @parent_ids, 1);
    ok($parent_ids[0], $f4_id);

    my @docs;
    foreach (1..5) {
	$docs[$_] = $objdb->insert_doc
	    (-parent => $folder[4],
	     -content => "Eins von fünfen",
	     -title => WE::Util::LangString->new(en => "Move test $_",
						 de => "Bewegen Test $_",
						),
	    );
	ok($docs[$_]->is_doc, 1);
    }
    ok(scalar $objdb->children_ids($f4_id), 6);
    $objdb->move($doc4, undef, -after => $docs[5]);
    my(@children_ids) = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[-1], $doc4->Id);

    $objdb->move($doc4, undef, -after => $docs[1]);
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[1], $doc4->Id);

    $objdb->move($doc4, undef, -before => $docs[1]);
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[0], $doc4->Id);

    # null operation
    $objdb->move($doc4, undef, -before => $children_ids[0]);
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[0], $doc4->Id);

    # null operation
    $objdb->move($doc4, undef, -after => $children_ids[0]);
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[0], $doc4->Id);

    $objdb->move($doc4, undef, -to => "last");
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[-1], $doc4->Id);

    $objdb->move($doc4, undef, -to => "first");
    @children_ids = $objdb->children_ids($f4_id);
    ok(scalar @children_ids, 6);
    ok($children_ids[0], $doc4->Id);

    # move folders
    ok(scalar $objdb->children_ids($f3_id), 1);
    $objdb->move($f4_id, undef, -target => $f3_id);
    ok(scalar $objdb->children_ids($f3_id), 2);
}

{
    # test walk
    # count the number of objects under $folder[3]
    my $obj_count = 0;
    my $n;
    my $ret = $objdb->walk
	($f3_id, sub {
	     my($id, $ref) = @_;
	     die "In walk" if !defined $id;
	     $$ref++;
	     ++$n;
	 }, \$obj_count);
    ok($n, 8);
    ok($obj_count, 8);
}

{
    # test preorder walk
    # count the number of objects under $folder[3]
    my $obj_count = 0;
    my $n;
    my $ret = $objdb->walk_preorder
	($f3_id, sub {
	     my($id, $ref) = @_;
	     die "In walk_preorder" if !defined $id;
	     $$ref++;
	     ++$n;
	 }, \$obj_count);
    ok($n, 9);
    ok($obj_count, 9); # one more than in postorder walk
}

{
    # test preorder walk
    # all children should see their parents
    my %obj_seen;
    my $ok = 1;
    eval {
	$objdb->walk_preorder($f3_id, sub {
	    my($id) = @_;
	    die "In walk_preorder (2nd test)" if !defined $id;
	    if ($id != $f3_id) {
		foreach my $pid ($objdb->parent_ids($id)) {
		    if (!exists $obj_seen{$pid}) {
			$ok = 0;
			die; # break prematurely
		    }
		}
	    }
	    $obj_seen{$id}++;
	});
    };
    ok($ok);
}

{
    # test preorder walk with prune

    my %obj_seen; # all objects
    my $n;
    my $ret = $objdb->walk_preorder
	($root_obj, sub {
	     my($id) = @_;
	     die "In walk_preorder (test with prune)" if !defined $id;
	     $obj_seen{$id}++;
	     ++$n;
	 });
    ok($n, 13);
    ok(join(" ", sort keys %obj_seen),"0 1 10 11 12 13 14 15 16 2 4 5 6");
}

{
    my %obj_seen2; # all objects except ...
    my $n;
    my $ret = $objdb->walk_preorder
	($root_obj, sub {
	     my($id) = @_;
	     die "In walk_preorder (4th test)" if !defined $id;
	     $obj_seen2{$id}++;
	     ++$n;
	     if ($id == $folder[3]->Id) { # "Titel Menü 4"
		 $WE::DB::Obj::prune = 1;
		 return $n;
	     }
	 });
    ok($n, 5);
    ok(join(" ", sort keys %obj_seen2),"0 1 2 4 6");
}

{
    # test prepostorder walk
    my $s = "";
    my $level = 0;
    my %level_count;
    my $start_id = $f3_id;
    my $ret = $objdb->walk_prepostorder
	($start_id,
	 sub {
	     my($id) = @_;
	     my $obj = $objdb->get_object($id);
	     if ($obj->is_folder) {
		 if ($id ne $start_id) {
		     $s .= "\n";
		 }
		 $s .= " "x$level . "<";
		 $level++;
		 $level_count{$level} = 0;
	     } else {
		 $level_count{$level}++;
		 if ($level_count{$level} > 1) {
		     $s .= ", ";
		 } else {
		     $s .= ": ";
		 }
	     }
	     $s .= $id;
	 },
	 sub {
	     my($id) = @_;
	     my $obj = $objdb->get_object($id);
	     if ($obj->is_folder) {
		 $s .= ">\n";
		 $level--;
	     }
	 }
	);
    ok($s, <<EOF);
<4: 10
 <5: 11, 12, 13, 14, 15, 16>
>
EOF
}


{
    # test walk up
    my @path;
    my $n;
    my $ret = $objdb->walk_up
	($doc4, sub {
	     my($id) = @_;
	     die "In walk_up" if !defined $id;
	     push @path, $id;
	     ++$n;
	 });
    ok($n, 3);
    ok("@path", "0 4 5");
}

{
    # test walk up preorder
    my @path;
    my $n;
    my $ret = $objdb->walk_up_preorder
	($doc4, sub {
	     my($id) = @_;
	     die "In walk_up_preorder" if !defined $id;
	     unshift @path, $id;
	     ++$n;
	 });
    ok($n, 4);
    ok("@path", "0 4 5 " . $doc4->Id);
}

{
    # check copy
    ok(scalar $objdb->children_ids($folder[1]), 0);
    my $new_doc = $objdb->copy($doc4, $folder[1]);
    ok(scalar $objdb->children_ids($folder[1]), 1);
    ok(($objdb->parent_ids($new_doc))[0], $folder[1]->Id);
    ok($objdb->content($new_doc), $objdb->content($doc4));
    ok($new_doc->Title->{'en'}, $doc4->Title->{'en'});
    ok($new_doc->Id ne $doc4->Id, 1);

    eval { $objdb->copy($folder[1], $folder[2]) };
    ok($@ ne "", 1);
    $objdb->copy($new_doc, $folder[1]);
    ok(scalar $objdb->children_ids($folder[1]), 2);
    ok($objdb->content($new_doc), $objdb->content(($objdb->children_ids($folder[1]))[-1]));
    eval { $objdb->copy($new_doc, $doc4) };
    ok($@ ne "", 1);

    # check recursive copy
    my @res = $objdb->copy($folder[1], $folder[0]);
    ok(scalar @res, 3);
    ok(scalar $objdb->children_ids($folder[0]), 1);
    my $copied_folder = ($objdb->children($folder[0]))[0];
    ok(ref $copied_folder, "WE::Obj::Folder");
    ok($copied_folder->Title, $folder[1]->Title);
    ok(scalar $objdb->children_ids($copied_folder),
       scalar $objdb->children_ids($folder[1]));

    # check non-recursive folder copy
    @res = $objdb->copy($folder[1], $folder[0], -recursive => 0);
    ok(scalar @res, 1);
    ok(scalar $objdb->children_ids($folder[0]), 2);
    $copied_folder = ($objdb->children($folder[0]))[-1];
    ok(ref $copied_folder, "WE::Obj::Folder");
    ok($copied_folder->Title, $folder[1]->Title);
    ok(scalar $objdb->children_ids($copied_folder), 0);

}

{
    # versions
    ok(scalar $objdb->version_ids($doc4), 0);
    $objdb->ci($doc4);
    ok(scalar $objdb->version_ids($doc4), 1);
    my $version = ($objdb->versions($doc4))[0];
    ok(ref $version, ref $doc4);
    ok($version->Title->{en}, $doc4->Title->{en});
    ok($version->Version_Number, "1.0");
    ok($version->Version_Owner, $r->CurrentUser);
    ok($version->Version_Comment, undef);
    my $version_content = $objdb->content($version);
    my $version_title   = $version->Title;
    $objdb->replace_content($doc4, "neu content for doc4");
    ok($objdb->content($version), $version_content);
    $doc4->Title("New title for doc4");
    $doc4 = $objdb->replace_object($doc4);
    $version = ($objdb->versions($doc4))[0];
    ok($version->Title->{en}, $version_title->{en});

    $version = $objdb->ci($doc4);
    ok(scalar $objdb->version_ids($doc4), 2);
    ok($version->Id, ($objdb->versions($doc4))[-1]->Id);
    ok($version->Version_Number, "1.1");

    $version = $objdb->ci($doc4,
			  -log => "Das ist eine Logmessage",
			  -number => "2.0");
    ok(scalar $objdb->version_ids($doc4), 3);
    ok($version->Id, ($objdb->versions($doc4))[-1]->Id);
    ok($version->Version_Number,  "2.0");
    ok($version->Version_Comment, "Das ist eine Logmessage");

    my $doc4_id = $doc4->Id;
    $version = $objdb->co($doc4, -version => "2.0");
    ok(scalar $objdb->version_ids($doc4), 3);
    ok($version->Id, $doc4_id);
    $version = $objdb->get_object($doc4_id);
    ok($version->Id, $doc4_id);
    ok($version->Version_Number, "2.0");
    ok($version->Version_Comment, "Das ist eine Logmessage");
    ok($objdb->content($version),
       $objdb->content(($objdb->versions($version))[-1]));

    # get latest version
    my $latest = $objdb->co($doc4);
    ok($latest->Id, $doc4_id);
    ok($latest->Id, $version->Id);
    ok($latest->Version_Number, $version->Version_Number);

    # trim all but the newest version
    {
	$objdb->ci($doc4,
		   -log => "Das Neueste vom Neuesten",
		   -number => "3.0",
		   -trimold => 2);
	ok(scalar $objdb->version_ids($doc4), 2);
	my $v = $objdb->get_object(($objdb->version_ids($doc4))[-1]);
	ok($v->Version_Number, '3.0');
    }

    # create more than 10 subversions:
    {
	for my $subv (1 .. 11) {
	    $objdb->ci($doc4,
		       -log => "Subversion 3.$subv",
		      );
	    ok(scalar $objdb->version_ids($doc4), 2+$subv);
	    my $v = $objdb->get_object(($objdb->version_ids($doc4))[-1]);
	    ok($v->Version_Number, '3.'.$subv);
	}
    }

    $doc4 = $version;
}

{
    # Locking
    ok($objdb->is_locked($doc4), 0);
    $objdb->lock($doc4, -type => "SessionLock");
    $doc4 = $objdb->get_object($doc4->Id);
    ok($doc4->LockedBy, $r->CurrentUser);
    ok($doc4->LockType, 'SessionLock');
    ok($objdb->is_locked($doc4), 0);
    $objdb->lock($doc4, -type => "PermanentLock");
    ok($objdb->is_locked($doc4), 0);
    $doc4 = $objdb->unlock($doc4);
    ok($objdb->is_locked($doc4), 0);
    $doc4 = $objdb->get_object($doc4->Id);
    ok($doc4->LockedBy, undef);
    ok($doc4->LockType, undef);

    my $save_user = $r->CurrentUser;
    ok($r->login("motu", "utom"), 1);
    $doc4 = $objdb->lock($doc4, -type => "PermanentLock");
    ok($objdb->is_locked($doc4), 0);

    $r->CurrentUser($save_user); # Hack
    ok($objdb->is_locked($doc4), 1);

    $r->CurrentUser("motu");
    $r->logout("motu");
    $r->CurrentUser($save_user);

    ok($objdb->is_locked($doc4), 1);

    ok($r->login("motu", "utom"), 1);
    $doc4 = $objdb->lock($doc4, -type => "SessionLock");
    ok($objdb->is_locked($doc4), 0);

    $r->CurrentUser($save_user); # Hack
    ok($objdb->is_locked($doc4), 1);

    $r->CurrentUser("motu");
    $r->logout("motu");
    $r->CurrentUser($save_user);

    ok($objdb->is_locked($doc4), 0);

    $doc4 = $objdb->unlock($doc4);
}

{
    # depth check
    ok(join("#", $objdb->depth($objdb->root_object)),"1#1");
    ok(join("#", $objdb->depth($doc4)),"4#4");
    # XXX check for different depths missing
}

{
    # pathobjects and pathobjects_with_cache check
    my $get_title = sub {
	join("/", map { WE::Util::LangString::langstring($_->Title) } @_);
    };

    for my $meth (qw(pathobjects pathobjects_with_cache)) {
	my $cache;
	ok($get_title->($objdb->$meth($objdb->root_object, undef, $cache)), "Root of the site");
	ok($get_title->($objdb->$meth($doc4, undef, $cache)), "Root of the site/Titel Menü 4/Titel Menü 5/New title for doc4");
	ok($get_title->($objdb->$meth($doc4, $folder[4], $cache)), "New title for doc4");
	ok($get_title->($objdb->$meth($folder[0], $objdb->root_object, $cache)), "Titel Menü 1");
	ok($get_title->($objdb->$meth($folder[0], undef, $cache)), "Root of the site/Titel Menü 1");
    }
}

{
    ok($objdb->is_ancestor($doc4, $objdb->root_object));
    ok($objdb->is_ancestor($doc4, $folder[4]));
    ok($objdb->is_ancestor($folder[4], $objdb->root_object));
    ok(!$objdb->is_ancestor($objdb->root_object, $doc4));
    ok(!$objdb->is_ancestor($folder[4], $doc4));
    ok(!$objdb->is_ancestor($objdb->root_object, $folder[4]));
}

{
    # pathname check
    ok($objdb->pathname($objdb->root_object), "/");
    ok($objdb->pathname($doc4), "/Titel Menü 4/Titel Menü 5/New title for doc4.html");
    ok($objdb->pathname($doc4, $folder[4]), "New title for doc4.html");
    ok($objdb->pathname($folder[0], $objdb->root_object), "Titel Menü 1");

    ok($objdb->pathname2id("/Titel Menü 4/Titel Menü 5/New title for doc4.html"),
       $doc4->Id);
    ok($objdb->pathname2id("/"), $objdb->root_object->Id);
    ok($objdb->pathname2id("gregueh uiehgruifrehgier/hfreihgreuioh ghreighuer/hfgioerghre", $folder[4]), undef);
    ok($objdb->pathname2id("/gregueh uiehgruifrehgier/hfreihgreuioh ghreighuer/hfgioerghre"), undef);
    ok($objdb->pathname2id("New title for doc4.html", $folder[4]), $doc4->Id);
}

{
    # insert document with auto-set title
    my $o = $objdb->insert_doc
	(-parent => $folder[4],
	 -file => "$FindBin::RealBin/$FindBin::RealScript",
	 -ContentType => "application/x-perl",
	 -Basename => 'BASE',
	 -Name => "wrong_named_object",
	 -WWWAuth => "group=auth,user=ole",
	);
    ok($o->is_doc, 1);
    ok($o->Title, "90_sample");
    ok($o->Basename, 'BASE');
    ok($o->Name, "wrong_named_object");
    ok($objdb->name_to_objid("wrong_named_object"), $o->Id);
    ok($objdb->pathname($o, $folder[4]), 'BASE');

    $o->Name("named_object");
    $objdb->replace_object($o);
    my $o2 = $objdb->get_object($o->Id);
    ok($o2->Name, "named_object");
    ok($objdb->name_to_objid("named_object"), $o->Id);

    $o = $objdb->insert_doc
	(-parent => $folder[3],
	 -file => "$FindBin::RealBin/$FindBin::RealScript",
	 -ContentType => "application/x-perl",
	);
    ok($o->is_doc, 1);
    ok($o->Basename, '90_sample.t');
    ok($objdb->pathname($o, $folder[3]), '90_sample.t');

}

{
    # export
    # XXX hmmmm.... seems that there are two export methods: one in WE::Export
    # and another in WE_Singlesite::Root
    my $export;
    eval q{$export = $r->export_db(-as => 'perl', -db => ['ObjDB', 'UserDB', 'OnlineUserDB']);};
    if (defined $connect && $connect == 0) {
	ok($@ =~ /The export_db method requires a permanent connection/, 1);
	skip("export_db requires a permanent connection",1);
    } else {
	ok($export =~ /ObjDB.*UserDB.*OnlineUserDB/, 1);

	my $r2 = $root_class->new(-rootdir => $test2dir,
				  -connect => 1);
	$r2->init;
	$r2->delete_db_contents;
	$r2->import_db(-string => $export, -as => 'perl');
	$r2->disconnect;
	ok(1);# XXX check contents in t/test2
    }
}

{
    # search content
    my @c = $r->ContentDB->search_fulltext("neu coNtenT");
    my @c1 = sort @c;
    ok(scalar @c > 0, 1);
    my $ok = 1;
    foreach my $c (@c) {
	my $s = $r->ContentDB->get_content($c);
	if ($s !~ /neu content/s) {
	    $ok = 0;
	    last;
	}
    }
    ok($ok);

    @c = $r->ContentDB->search_fulltext("NeU ConTenT", -casesensitive => 1);
    ok(scalar @c == 2, 1); # this test script should be two times in the db

    @c = $r->ContentDB->search_fulltext("neu content", -regexp => 1);
    my @c2 = sort @c;
    ok(scalar @c1, scalar @c2);
}

# create and leave some entries to have a nice deep database sample
$objdb->insert_doc(-title => new_langstring(de => "Ein Dok in Verzeichnis 3",
					    en => "A document in folder three"),
		   -parent => $f3_id,
		   -content => "<body>Ein <i>bisschen</i> content...</body>",
		   -Name => "test for 93_navigation_plugin",
		   -Release_State => "released",
		  );
my $new_f = $objdb->insert_folder(-title => "Ein Folder in 3",
				  -parent => $f3_id,
				  -WWWAuth => "eserte",
				 );
my $new_doc1 = $objdb->insert_doc
    (-title => "Ein Dok in Verzeichnis 3/Sub",
     -parent => $new_f->Id,
     -content => "Noch mehr content, diesmal aber text",
     -ContentType => "text/plain",
     -WWWAuth => "group=auth,group=foo,user=ole",
    );
ok($new_doc1->ContentType, "text/plain");
if (-r "/oo/onlineoffice/homepage/images/oo_titel.gif") {
    my $img = $objdb->insert_doc
	(-title => "Das waren noch Zeiten",
	 -parent => $new_f->Id,
	 -file => "/oo/onlineoffice/homepage/images/oo_titel.gif",
	 -WWWAuth => "group=auth,group=foo,user=ole",
	);
    ok($img->ContentType, "image/gif");
} else {
    my $img = $objdb->insert_doc
	(-title => "Das waren noch Zeiten",
	 -parent => $new_f->Id,
	 -content => "Dummy content: /oo/onlineoffice/homepage/images/oo_titel.gif",
	 -WWWAuth => "group=auth,group=foo,user=ole",
	);
    ok($img->ContentType, "text/html");
}
my $new_doc2 = $objdb->insert_doc
    (-title => "Dieses Test-Skript",
     -parent => $new_f->Id,
     -file => "$FindBin::RealBin/$FindBin::RealScript",
     -ContentType => "application/x-perl",
     -WWWAuth => "group=auth,group=foo",
    );
ok($new_doc2->ContentType, "application/x-perl");

{
    my $search_objid = $objdb->name_to_objid("named_object");
    ok(defined $search_objid, 1);
    my $search_obj = $objdb->get_object($search_objid);
    ok($search_obj->isa('WE::Obj'), 1);
    ok($search_obj->Title, "90_sample");

    my $content = <<'EOF';
$outdata = {'data' => {'de' => {'title' => 'Gesundheit & Umwelt','ct' => [{'name' => '&#134;berschrift','type' => 'boldtext','text' => 'Gesundheit & Umwelt'},{'name' => 'Copytext','type' => 'text','text' => 'Lorem ipsum dolor sit amet ...'},{'name' => 'Teaser','type' => 'free','cancontain' => ['teaserlink'],'ct' => [{'number' => 1,'name' => 'Wirtschaft / fetter text','type' => 'teaserlink','page' => 112}]}]},'pageid' => 107,'nodel' => '0','language' => 'de','section' => 'n1','visible' => 1,'pagetype' => 'gabel'}};
EOF
    $objdb->replace_content($search_objid, $content);
    ok($objdb->content($search_objid), $content);
    require WE_Content::PerlDD;
    my $content_obj = WE_Content::PerlDD->new(-file => $r->ContentDB->filename($search_objid));
    ok(UNIVERSAL::isa($content_obj, 'HASH'));
    ok($content_obj->{Object});
    ok(exists $content_obj->{Object}->{data});
    ok(exists $content_obj->{Object}->{data}->{de});
    ok($content_obj->{Type}, 'content');
}

{
    my $sequence = WE::Obj::Sequence->new;
    $sequence->Title("Eine Sequenz");
    $sequence->Name("sequence-test");
    ok($sequence->is_sequence);
    ok($sequence->is_folder);
    ok($sequence->Title, "Eine Sequenz");
    my $seq_obj = $objdb->insert($sequence, -parent => $new_f);

    $objdb->insert_doc(-parent => $seq_obj,
		       -content => "Erstes Dokument in der Sequenz",
		       -Title => "SeqDoc 1",
		      );
    $objdb->insert_doc(-parent => $seq_obj,
		       -content => "Zweites Dokument in der Sequenz",
		       -Title => "SeqDoc 2",
		      );

    ok($objdb->children_ids($seq_obj), 2);
}

{
    # is active checks
    my $doc = $objdb->get_object($doc4->Id);

    my $future = epoch2isodate(time + 10000);
    my $past   = epoch2isodate(time - 10000);

    $doc->Release_State("released");
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 1);

    $doc->Release_State("inactive");
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 0);

    $doc->Release_State("released");
    $doc->TimeOpen($past);
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 1);

    $doc->TimeOpen($future);
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 0);

    $doc->TimeOpen("");
    $doc->TimeExpire($past);
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 0);

    $doc->TimeExpire($future);
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 1);

    $doc->TimeExpire("");
    $objdb->replace_object($doc);
    ok($objdb->is_active_page($doc), 1);
}

{
    # trim all versions
    my $doc = $objdb->insert_doc(-parent => $root_obj,
				 -title => "Trim all versions test",
				 -content => "blabla",
				);
    for (1..2) {
	$objdb->ci($doc, -log => "Create a version");
    }
    ok($objdb->version_ids($doc), 2);
    $objdb->trim_old_versions($doc, -all => 1);

    my @versions = $objdb->version_ids($doc);
    ok(scalar @versions, 0);

    $objdb->remove($doc);
    my $doc_again = $objdb->get_object($doc->Id);
    ok(!defined $doc_again); # really removed

    my $version_again = $objdb->get_object($versions[0]);
    ok(!defined $version_again); # versions are also removed
}

# Add new tests which introduce or delete objects here!

#print STDERR $objdb->dump;

my $integrity_check = $objdb->check_integrity;
ok($integrity_check->has_errors, 0, "Integrity check");
if ($integrity_check->has_errors) {
    require Data::Dumper;
    print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	Data::Dumper->new([$integrity_check],[])->Indent(1)->Useqq(1)->Dump;
}

my $integrity_check2 = $r->ContentDB->check_integrity($objdb);
ok($integrity_check2->has_errors, 0, "Integrity check for ContentDB");
if ($integrity_check2->has_errors) {
    require Data::Dumper;
    print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" .
	Data::Dumper->new([$integrity_check2],[])->Indent(1)->Useqq(1)->Dump;
}

$r->disconnect;
#XXX NYI $objdb->DESTROY;
ok(tied %{$objdb->{DB}}, undef);

if ($t0) {
    my $elapsed = Time::HiRes::tv_interval($t0);
    $bench{"root class: @{[out($root_class)]}; connect: @{[out($connect)]}, serializer; @{[out($serializer)]}"} = $elapsed;
}

} # connect
} # serializer
} # root class

print join("\n", map {
    sprintf "# %s: %.2fs", $_, $bench{$_}
} sort {
    $bench{$a} <=> $bench{$b}
} keys %bench), "\n";

sub out {
    !defined $_[0] ? "undefined" : $_[0];
}

__END__
