#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 96_tksoap.t,v 1.1.1.1 2002/08/06 18:35:00 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Safe;

use FindBin;
use WE::Obj;
use WE::Util::LangString qw(langstring);

BEGIN {
    if (!eval q{
	use Test;
        use Tk;
	use Tk::Tree;
	use Tk::NoteBook;
	use Tk::ObjEditor;
	use SOAP::Lite;
	1;
    }) {
	print "# tests only work with installed Test, Tk, Tk::Tree, Tk::NoteBook, Tk::ObjEditor and SOAP::Lite modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

#BEGIN { plan tests => 9 }
BEGIN { plan tests => 1 }#XXX

ok(1);
exit(0);#XXX this test tests nothing anymore !!!!!!!!
WE::Obj->use_classes(qw/:all/);

use Getopt::Long;
# XXX start server automatically!
my $proxy = "http://localhost:8123/";
my $uri   = "WE_Sample/Root";
my $uri2  = "WE/DB/Obj";

if (!GetOptions("proxy=s" => \$proxy)) {
    die "usage!";
}

warn <<EOF;

   If you have failures in this script, then please make sure that a
   SOAP proxy is running. Start the proxy with:

      perl -Mblib lib/WE/Server/SOAP.pm <portnumber>

   Then restart the test script with

      perl -Mblib $0 -proxy http://localhost:<portnumber>

EOF

my $soap = SOAP::Lite->proxy($proxy);
$soap->uri($uri) if $uri;
ok(defined $soap, 1);

my $soap2 = SOAP::Lite->proxy($proxy);
$soap2->uri($uri2) if $uri2;
ok(defined $soap2, 1);

my $rootdb = $soap->call('new',
			 #-rootdir => "$FindBin::RealBin/test",
			 #-rootdir => "/home/e/eserte/work/WE_Framework/t/test",
			 -rootdir => "/home/e/eserte/public_html/sample/wwwroot/cgi-bin/we_data",
			 -connect => 0,
			 -locking => 1)->result;
#my $rootdb = $soap->call('get_db' => 'WE_Sample::Root', 'sample-eserte');
ok(ref $rootdb, 'WE_Sample::Root');

ok($soap->call('login' => $rootdb,
	       "motu", "utom")->result, 1);

my $objdb = $soap->call('ObjDB' => $rootdb)->result;
ok(ref $objdb, 'WE::DB::Obj');

my $root_obj = $soap2->call('root_object' => $objdb)->result;

my $mw = new MainWindow;
foreach my $w (qw/Tree ObjEditor Text ROText/) {
    $mw->optionAdd("*$w*background", "white");
}

my $tree = $mw->Scrolled("Tree", -scrollbars => "osoe",
			 -drawbranch => 1,
			)->packAdjust(qw/-fill both -expand 1 -side left/);
traverse_tree($root_obj, "");
$tree->autosetmode(1);

use vars qw($popup_entry $popup_id $popup_menu);
my $real_tree = $tree->Subwidget("scrolled");
$popup_menu = $real_tree->Menu(-tearoff => 0,
			  -disabledforeground => "darkblue");
$popup_menu->command(-label => "File:",
		     -state => "disabled");
#XXX Add code is very rough...
$popup_menu->command
    (-label => "Add empty document",
     -command => sub {
	 my $pid = _get_parent_or_self($popup_id);
	 $soap2->call('insert_doc' => $objdb,
		      -Title => "New empty document",
		      -parent => $pid);
	 $soap2->call(flush => $objdb);
	 refresh_current_subtree($popup_entry);
     });
$popup_menu->command
    (-label => "Add document/image",
     -command => sub {
	 my $pid = _get_parent_or_self($popup_id);
	 my $file = $tree->getOpenFile;
	 return unless (defined $file and -r $file);
	 use File::Basename;
	 my $title = basename($file);
	 $soap2->call('insert_doc' => $objdb,
		      -file => $file,
		      -Title => $title,
		      -parent => $pid);
	 $soap2->call(flush => $objdb);
	 refresh_current_subtree($popup_entry);
     });
$popup_menu->command
    (-label => "Add folder",
     -command => sub {
	 my $pid = _get_parent_or_self($popup_id);
	 $soap2->call('insert_folder' => $objdb,
		      -Title => "New folder",
		      -parent => $pid);
	 $soap2->call(flush => $objdb);
	 refresh_current_subtree($popup_entry);
     });
$popup_menu->command
    (-label => "Delete",
     -command => sub {
	 return unless $mw->messageBox(-message => "Are you sure?",
				       -icon => 'question',
				       -type => 'YesNo') =~ /yes/i;
	 my $pid = $soap2->call('parent_ids' => $objdb, $popup_id)->result;
	 $soap2->call(unlink => $objdb, $popup_id, $pid);
	 $soap2->call(flush => $objdb);
	 refresh_current_subtree($popup_entry);
     });
$popup_menu->separator;
$popup_menu->command(-label => "Refresh tree",
		     -command => sub {
			 $tree->delete("all");
			 traverse_tree($root_obj,''); # XXX re-fetch root too
			 #$tree->autosetmode(1);
		     });
if ($real_tree->can("menu") &&
    $real_tree->can("PostPopupMenu") && $Tk::VERSION >= 800) {
    $real_tree->menu($popup_menu);
    $real_tree->Tk::bind('<3>' => sub {
	my $w = $_[0];
	my $e = $w->XEvent;
  	$popup_entry = $w->GetNearest($e->y, 0);
  	return unless defined $popup_entry;
	my $title = $tree->entrycget($popup_entry, '-text');
  	$popup_id = $tree->entrycget($popup_entry, '-data');
  	$popup_menu->entryconfigure(0, -label => $title);
	$w->PostPopupMenu($e->X, $e->Y);
    });
}
my $objed;
my $act_obj;
my $stored_obj;
$tree->configure
    (-command => sub {
	 my $entry = $_[0];
	 my $id = $tree->entrycget($entry, '-data');
	 $act_obj = $soap2->call('get_object' => $objdb, $id)->result;
	 make_objeditor();
     });

sub _get_parent_or_self {
    my($oid) = @_;
    my $obj = $soap2->call(get_object => $objdb, $oid)->result;
    if (!$obj) {
	die "Can't get object by id $oid";
    }
    return $obj->Id if ($obj->is_folder);
    my $pid = $soap2->call('parent_ids' => $objdb, $oid)->result;
    $pid;
}

sub make_objeditor {
    if (Tk::Exists($objed)) {
	$objed->destroy;
    }
    $objed = $mw->Frame->pack(qw/-fill both -expand 1 -side left/);
    my $bf = $objed->Frame->pack(qw/-fill x/);
    $bf->Button(-text => 'Cancel',
		-command => sub {
		    $objed->destroy;
		})->pack(-side => 'left');
    my $get_content;
    $bf->Button(-text => 'Save',
		-command => sub {
		    use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$act_obj],[]); # XXX
		    $soap2->call('replace_object' => $objdb, $act_obj);
                    if ($get_content) {
			my $new_content = $get_content->();
			$soap2->call('replace_content' => $objdb,
				     $act_obj->Id, $new_content);
		    }
		    $soap2->call(flush => $objdb);
		    $objed->destroy;
		})->pack(-side => 'left');
    if (1) {
	$bf->Button(-text => 'Save stored object',
		    -command => sub {
			use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$stored_obj],[]); # XXX
			$soap2->call('store_stored_obj' => $objdb, $stored_obj);
			$soap2->call(flush => $objdb);
			$objed->destroy;
		    })->pack(-side => 'left');
    }
    my $nb = $objed->NoteBook->pack(qw/-fill both -expand 1/);;
    my $p1 = $nb->add("Attributes", -label => "Attributes");
    $p1->ObjEditor(caller => $act_obj,
		   direct => 1,
		  )->pack(qw/-fill both -expand 1/);

    if ($act_obj->is_doc) {
	my $p2 = $nb->add("Content", -label => "Content");
	my $content = $soap2->call('content' => $objdb, $act_obj->Id)->result;
	if ($act_obj->ContentType eq 'application/x-perl') {
	    my $c = new Safe;
	    my $perl_obj = $c->reval($content);
	    if ($perl_obj) {
		$p2->ObjEditor(caller => $perl_obj,
			       direct => 1,
			      )->pack(qw/-fill both -expand 1/);
		$get_content = sub {
		    use Data::Dumper;
		    my $dd = new Data::Dumper([$perl_obj],['outdata']);
		    $dd->Indent(0);
		    $dd->Dump;
		};
	    }
	} elsif ($act_obj->ContentType =~ /^text\//) {
	    my $txt = $p2->Scrolled("Text", -scrollbars => "osoe"
				   )->pack(qw/-fill both -expand 1/);
	    $txt->insert("end", $content);
	    $get_content = sub {
		$txt->get("1.0", "end - 1c");
	    };
	} elsif ($act_obj->ContentType =~ /^image\/(.*)/) {
	    my $subtype = $1;
	    use MIME::Base64;
	    eval {
		if ($subtype eq 'jpeg') { require Tk::JPEG }
		elsif ($subtype eq 'png') { require Tk::PNG }
		elsif ($subtype eq 'tiff') { require Tk::TIFF }
		my $p = $mw->Photo(-data => encode_base64($content));
		my $l = $p2->Label(-text => langstring($act_obj->Title),
				   -image => $p)->pack(qw/-fill both -expand 1/);
		#	    $p->delete; # XXX !!!!!
		# no saving for now...
	    }; warn $@ if $@;
	} else {
	    my $txt = $p2->Scrolled("ROText", -scrollbars => "osoe"
				   )->pack(qw/-fill both -expand 1/);
	    $txt->insert("end", $content);
	    # no saving
	}
    }

    undef $stored_obj;
    if (1) {
	my $p3 = $nb->add("Storedobject", -label => "Stored object");
	$stored_obj = $soap2->call('get_stored_obj' => $objdb, $act_obj->Id)->result;
	if ($stored_obj) {
	    $p3->ObjEditor(caller => $stored_obj,
			   direct => 1,
			  )->pack(qw/-fill both -expand 1/);
	}
    }
}

sub traverse_tree_slow {
    my($obj, $parententry) = @_;
#warn "$obj $parententry";
    my $entry = ($parententry eq '' ? '' : $parententry . ".") . $obj->Id;
    $tree->add($entry, -itemtype => 'imagetext',
	       $obj->is_folder
	       ? (-image => $mw->Getimage('folder'))
	       : (-image => $mw->Getimage('file')),
	       -text => langstring($obj->Title), -data => $obj->Id);
    my $s = $soap2->call('children' => $objdb, $obj->Id);
    my(@children) = ($s->result, $s->paramsout);
    #use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\@children],[]); # XXX
    foreach my $cobj (@children) {
	traverse_tree($cobj, $entry);
    }
}

sub traverse_tree { # fast
    my($obj, $parententry) = @_;
    my $fast_tree = $soap2->call(fast_tree => $objdb, $obj->Id)->result;
    _traverse_tree_fast($fast_tree, $parententry);
}

sub _traverse_tree_fast {
    my($t, $parententry) = @_;
    my $entry;
    foreach my $obj (@$t) {
	if (UNIVERSAL::isa($obj,'HASH')) {
	    $entry = ($parententry eq '' ? '' : $parententry . ".") . $obj->{Id};
	    $tree->add($entry, -itemtype => 'imagetext',
		       $obj->{'isFolder'}
		       ? (-image => $mw->Getimage('folder'))
		       : (-image => $mw->Getimage('file')),
		       -text => langstring($obj->{Title}), -data => $obj->{Id});
	} else {
	    _traverse_tree_fast($obj, $entry);
	}
    }
}

sub refresh_current_subtree {
    $tree->delete("all");
    traverse_tree($root_obj); # XXX re-fetch root too
    $tree->autosetmode(1);
#XXX
return;
    my($entry) = @_;
    (my $parent_entry = $entry) =~ s/\.[^\.]+$//;
    (my $parent_parent_entry = $parent_entry) =~ s/\.[^\.]+$//;
    my $id = $tree->entrycget($parent_entry, '-data');
    my $obj = $soap2->call(get_object => $objdb, $id)->result;
    $tree->delete("entry", $parent_entry);
warn "deleted $parent_entry, new under $parent_parent_entry";
    traverse_tree($obj, $parent_parent_entry);
}

MainLoop;
__END__
