#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 89_fs.t,v 1.5 2003/01/19 14:31:09 eserte Exp $
# Author: Slaven Rezic
#

# Depends on test 10_we_userdb.t

use strict;
use FindBin;

use File::Path;

use WE::Util::Support;
use WE::Util::LangString qw(new_langstring);

BEGIN {
    if (!eval q{
	use VCS 0.08;
	use VCS::Rcs 0.06; # to make sure my modifications are in
	use YAML 0.30;
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

{
    package WE_FS::Root;
    require WE::DB; # 5.00503 bug (?)
    use base qw(WE::DB);
    use WE::Obj;

    WE::Obj->use_classes(':all');
    WE::DB->use_databases(qw/FS User OnlineUser Name/);

    sub new {
	my($class, %args) = @_;
	my $self = {};
	bless $self, $class;

	my $root_dir = delete $args{-rootdir};
	my $db_dir = $root_dir . "/db";
	die "No -rootdir given" if !defined $root_dir;
	my $readonly = defined $args{-readonly} ? delete $args{-readonly} : 0;
	my $locking = defined $args{-locking} ? delete $args{-locking} : 1;

	$self->ObjDB        (WE::DB::FS->new($self, $root_dir,
					     -locking => $locking,
					     -connect  => $args{-connect},
					    ));
	$self->UserDB       (WE::DB::User->new($self, "$db_dir/userdb.db",
					       -readonly => $readonly));
	$self->OnlineUserDB (WE::DB::OnlineUser->new($self, "$db_dir/onlinedb.db",
						     -readonly => $readonly));
	$self->NameDB       (WE::DB::Name->new($self, "$db_dir/name.db",
					       -readonly => $readonly,
					       -connect  => $args{-connect},
					      ));
	$self->ContentDB    ($self->ObjDB); # fake...

	$self->UserDB->add_user("motu", "utom")
	    if !$self->UserDB->user_exists("motu");

	$self;
    }
    sub disconnect { }
}

eval 'require Time::HiRes';

BEGIN { plan tests => 252 }

if ($Test::VERSION <= 1.122) {
    $^W = 0; # too many warnings
}

my %bench;

my $testdir  = "$FindBin::RealBin/test4";
my $test1dir = "$FindBin::RealBin/test";
my $test2dir = "$FindBin::RealBin/test2";

rmtree([$testdir], 0, 0);

mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);
mkdir "$testdir/db", 0770;

mkdir $test2dir, 0770;
ok(-d $test2dir, 1);
ok(-w $test2dir, 1);

my $t0;
if (defined &Time::HiRes::gettimeofday) {
    $t0 = [Time::HiRes::gettimeofday()];
}

my $connect = 0; # XXX loop between 0 and 1?
my $r = new WE_FS::Root -rootdir => $testdir,
                        -connect => $connect,
    ;
ok(ref $r, 'WE_FS::Root');
$r->init;

my $objdb = $r->{ObjDB};
ok(ref $objdb, 'WE::DB::FS');

ok($r->is_allowed("bla", 0), 0); # no user

# set the user by hand ... normally it would be done with $t->identify
$r->CurrentUser("eserte");
ok($r->CurrentUser, "eserte");
$r->CurrentLang("de");
ok($r->CurrentLang, "de");

#XXX NYI $objdb->delete_db_contents;

my $root_obj = $objdb->root_object;
ok($root_obj->isa('WE::Obj::FolderObj'), 1);
ok($root_obj->isa('WE::Obj::Site'), 1);
ok($root_obj->is_folder, 1);
ok($objdb->is_root_object($root_obj));
ok($objdb->is_root_object($root_obj->Id));

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
    ok($fid ne "file:", 1, "not root object test failed");
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
ok($docid ne "file:", 1);
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
ok($doc2_id ne "file:", 1);
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
ok($doc3_id ne "file:", 1);
ok($doc3->isa('WE::Obj::DocObj'), 1);
ok($doc3->is_doc, 1);
ok(scalar $objdb->children_ids($f3_id), 1);
ok(scalar $objdb->parent_ids($doc3_id), 1);
my $f4_id = $folder[4]->Id;
ok(scalar $objdb->children_ids($f4_id), 0);
ok($objdb->exists($doc3_id), 1);

$doc3 = $objdb->insert_doc(-parent => $folder[3],
			   -content => "Noch mehr doc3",
			   -title => "Ein Titel",
			   -WWWAuth => "group=auth,user=ole",
			  );
ok($doc3->is_doc, 1);
$objdb->remove($doc3);

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
    $doc4 = $objdb->move($doc4, undef, -destination => $f4_id);
    $objdb->objectify_params($doc4);
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
#      $objdb->move($doc4, undef, -after => $docs[5]);
#      my(@children_ids) = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[-1], $doc4->Id);

#      $objdb->move($doc4, undef, -after => $docs[1]);
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[1], $doc4->Id);

#      $objdb->move($doc4, undef, -before => $docs[1]);
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[0], $doc4->Id);

#      # null operation
#      $objdb->move($doc4, undef, -before => $children_ids[0]);
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[0], $doc4->Id);

#      # null operation
#      $objdb->move($doc4, undef, -after => $children_ids[0]);
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[0], $doc4->Id);

#      $objdb->move($doc4, undef, -to => "last");
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[-1], $doc4->Id);

#      $objdb->move($doc4, undef, -to => "first");
#      @children_ids = $objdb->children_ids($f4_id);
#      ok(scalar @children_ids, 6);
#      ok($children_ids[0], $doc4->Id);

    # move folders
    ok(scalar $objdb->children_ids($f3_id), 1);
    $f4_id = $objdb->move($f4_id, undef, -target => $f3_id);
    $folder[4] = $objdb->get_object($f4_id);
    ok(scalar $objdb->children_ids($f3_id), 2);
}

{
    # test walk
    # count the number of objects under $folder[3]
    my $obj_count = 0;
    $objdb->walk($f3_id, sub {
		     my($id, $ref) = @_;
		     $$ref++;
		 }, \$obj_count);
    ok($obj_count, 8);
}

{
    # test preorder walk
    # count the number of objects under $folder[3]
    my $obj_count = 0;
    $objdb->walk_preorder($f3_id, sub {
		     my($id, $ref) = @_;
		     $$ref++;
		 }, \$obj_count);
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
	    if ($id ne $f3_id) {
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
    $objdb->walk_preorder($root_obj, sub {
			      my($id) = @_;
			      $obj_seen{$id}++;
			  });

    my %obj_seen2; # all objects except ...
    $objdb->walk_preorder($root_obj, sub {
			      my($id) = @_;
			      $obj_seen2{$id}++;
			      if ($id eq $folder[3]->Id) { # "Titel Menü 4"
				  $WE::DB::Obj::prune = 1;
				  return;
			      }
			  });

    ok(join(" ", sort keys %obj_seen),"file: file:/0000 file:/0001 file:/0003 file:/0003/0000 file:/0003/0004 file:/0003/0004/0000 file:/0003/0004/0001 file:/0003/0004/0002 file:/0003/0004/0003 file:/0003/0004/0004 file:/0003/0004/0005 file:/0005");
    ok(join(" ", sort keys %obj_seen2),"file: file:/0000 file:/0001 file:/0003 file:/0005");

}

$doc4 = $objdb->get_object("file:/0003/0004/0005");
{
    # test walk up
    my @path;
    $objdb->walk_up($doc4, sub {
			my($id) = @_;
			push @path, $id;
		    });
    ok("@path", "file: file:/0003 file:/0003/0004");
}

{
    # test walk up preorder
    my @path;
    $objdb->walk_up_preorder($doc4, sub {
				 my($id) = @_;
				 unshift @path, $id;
			     });
    ok("@path", "file: file:/0003 file:/0003/0004 " . $doc4->Id);
}

{
    # check copy
    ok(scalar $objdb->children_ids($folder[1]), 0);
    ok($objdb->exists($doc4));
    ok($objdb->exists($folder[1]));
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
    ok($version->Version_Number, "1.1");
    ok($version->Version_Owner, $r->CurrentUser);
    ok($version->Version_Comment, "Initial revision"); # XXX hmmm,
                                                       # sonst ist es leer?
    my $version_content = $objdb->content($version);
    my $version_title   = $version->Title;
    $objdb->replace_content($doc4, "neu content for doc4");
    ok($objdb->content($version), $version_content);
    $doc4->Title("New title for doc4");
    $doc4 = $objdb->replace_object($doc4);
    $version = ($objdb->versions($doc4))[0];
    ok($version->Title->{en}, $version_title->{en});

    $version = $objdb->ci($doc4);
    ok($version->Id, "version:1.2;/0003/0004/0005");
    ok(scalar $objdb->version_ids($doc4), 2, "Failed for doc id: " . $doc4->Id);
    ok($version->Id, ($objdb->versions($doc4))[-1]->Id);
    ok($version->Version_Number, "1.2");

    $version = $objdb->ci($doc4,
			  -log => "Das ist eine Logmessage",
			  -number => "1.3"); # XXX hier war mal 2.0,
    # aber VCS::Rcs ist buggy!
    ok(scalar $objdb->version_ids($doc4), 3);
    ok($version->Id, ($objdb->versions($doc4))[-1]->Id);
    ok($version->Version_Number,  "1.3");
    ok($version->Version_Comment, "Das ist eine Logmessage");

    my $doc4_id = $doc4->Id;
    $version = $objdb->co($doc4, -version => "1.3");
    ok(scalar $objdb->version_ids($doc4), 3);
    ok($version->Id, $doc4_id);
    $version = $objdb->get_object($doc4_id);
    ok($version->Id, $doc4_id);
    ## not here: objects with file:... id not have version attributes
    #ok($version->Version_Number, "1.3");
    #ok($version->Version_Comment, "Das ist eine Logmessage");
    ok($objdb->content($version),
       $objdb->content(($objdb->versions($version))[-1]));

    # get latest version
    my $latest = $objdb->co($doc4);
    ok($latest->Id, $doc4_id);
    ok($latest->Id, $version->Id);
    ok($latest->Version_Number, $version->Version_Number);

    # trim all but the newest version
    if (1) {
	skip(2, "-trimold is not yet implemented");
    } else {
	$objdb->ci($doc4,
		   -log => "Das Neueste vom Neuesten",
		   -number => "1.4", # XXX siehe oben (war mal 3.0)
		   -trimold => 2);
	ok(scalar $objdb->version_ids($doc4), 2);
	my $v = $objdb->get_object(($objdb->version_ids($doc4))[-1]);
	ok($v->Version_Number, '1.4');
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

    # some hackery:
    {
	my $u = WE::DB::User->new($r, "$test1dir/userdb.db");
	$u->add_user("motu","utom") if !$u->user_exists("motu");
    }
    $r->UserDB(WE::DB::User->new($r, "$test1dir/userdb.db",
				 -readonly => 1));

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
    # pathobjects check
    my $get_title = sub {
	join("/", map { WE::Util::LangString::langstring($_->Title) } @_);
    };

    ok($get_title->($objdb->pathobjects($objdb->root_object)), "Root of the site");
    ok($get_title->($objdb->pathobjects($doc4)), "Root of the site/Titel Menü 4/Titel Menü 5/New title for doc4");
    ## no multiple parents:
    #ok($get_title->($objdb->pathobjects($doc4, $folder[4])), "New title for doc4");
    ok($get_title->($objdb->pathobjects($folder[0], $objdb->root_object)), "Titel Menü 1");
    ok($get_title->($objdb->pathobjects($folder[0])), "Root of the site/Titel Menü 1");
}

{
    # pathname check
    ok($objdb->pathname($objdb->root_object), "/");
    ok($objdb->pathname($doc4), "/0003/0004/0005");
    ok($objdb->pathname($doc4, ($objdb->parent_ids($doc4))[0]), "0005");
    ok($objdb->pathname($folder[0], $objdb->root_object), "0000");

    ok($objdb->pathname2id("/0003/0004/0005"), $doc4->Id);
    ok($objdb->pathname2id("/"), $objdb->root_object->Id);
    ok($objdb->pathname2id("gregueh uiehgruifrehgier/hfreihgreuioh ghreighuer/hfgioerghre", $folder[4]), undef);
    ok($objdb->pathname2id("/gregueh uiehgruifrehgier/hfreihgreuioh ghreighuer/hfgioerghre"), undef);
    ok($objdb->pathname2id("/0003/0004/0005", $folder[4]), $doc4->Id);
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
    ok($o->Title, "89_fs");
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
    ok($o->Basename, '89_fs.t');
    ok($objdb->pathname($o, $folder[3]), '89_fs.t');

}

## XXX no exports for now...
#  {
#      # export
#      # XXX hmmmm.... seems that there are two export methods: one in WE::Export
#      # and another in WE_Singlesite::Root
#      my $export;
#      eval q{$export = $r->export_db(-as => 'perl', -db => ['ObjDB', 'UserDB', 'OnlineUserDB']);};
#      if (defined $connect && $connect == 0) {
#  	ok($@ =~ /The export_db method requires a permanent connection/, 1);
#  	skip("export_db requires a permanent connection",1);
#      } else {
#  	ok($export =~ /ObjDB.*UserDB.*OnlineUserDB/, 1);

#  	my $r2 = new WE_FS::Root -rootdir => $test2dir,
#  	                         -connect => 1;
#  	$r2->init;
#  	$r2->delete_db_contents;
#  	$r2->import_db(-string => $export, -as => 'perl');
#  	$r2->disconnect;
#  	ok(1);# XXX check contents in t/test2
#      }
#  }

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
    ok($search_obj->Title, "89_fs");

    my $content = <<'EOF';
+{'data' => {'de' => {'title' => 'Gesundheit & Umwelt','ct' => [{'name' => '&#134;berschrift','type' => 'boldtext','text' => 'Gesundheit & Umwelt'},{'name' => 'Copytext','type' => 'text','text' => 'Lorem ipsum dolor sit amet ...'},{'name' => 'Teaser','type' => 'free','cancontain' => ['teaserlink'],'ct' => [{'number' => 1,'name' => 'Wirtschaft / fetter text','type' => 'teaserlink','page' => 112}]}]},'pageid' => 107,'nodel' => '0','language' => 'de','section' => 'n1','visible' => 1,'pagetype' => 'gabel'}};
EOF
    require WE_Content::YAML;
    my $yaml_dump = WE_Content::YAML->new(-object => eval($content))->serialize();
    $objdb->replace_content($search_objid, $yaml_dump);
    ok($objdb->content($search_objid), $yaml_dump);
    my $content_obj = WE_Content::YAML->new(-file => $r->ContentDB->filename($search_objid));
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

#print STDERR $objdb->dump;

if (0) {
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
}

$r->disconnect;

if ($t0) {
    my $elapsed = Time::HiRes::tv_interval($t0);
    $bench{"fs"} = $elapsed;
}

print join("\n", map {
    sprintf "# %s: %.2fs", $_, $bench{$_}
} sort {
    $bench{$a} <=> $bench{$b}
} keys %bench), "\n";


__END__
