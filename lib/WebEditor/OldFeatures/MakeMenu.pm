package WebEditor::OldFeatures::MakeMenu;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use CGI qw(param);

# XXX
# This module is untested for a long time. Probably the
# get_released_children calls should be rooted in $objdb instead of $root
# now. Also there's too much project specific stuff hardcoded to be
# useable as a general purpose module.

######################################################################
#
# create the menu
#
sub makemenu {
    my $self = shift;

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;

    require Template;
    # create a dummy-menu:
    my @lines;
    my %menucolors = ("aussen","green",
		      "innen","red",
		      "company","blue");
    my $t = Template->new($self->Templateconf);
    my $templatevars = $self->Templatevars;
    foreach my $mnu (keys %menucolors) {
	foreach my $lng (@{ $c->project->sitelanguages }) {
	    my @lines=();
	    #traversemenu(0,\@lines,$lng);
	    my $outf = $c->paths->pubhtmldir."script/menuconfig_".$mnu."_".$lng.".js";
	    $templatevars->{'bgcolor'} = $menucolors{$mnu};
	    #### now the real work
  	    my $fldr_id = $objdb->name_to_objid($mnu);
  	    my @children = $root->get_released_children($fldr_id);
	    my $mcounter = 0;
  	    foreach my $child (@children) {
		next if (!$child->is_folder);
  		my $mtarget = "";
  		if (defined $child->IndexDoc) { $mtarget = $child->IndexDoc };
  		my $mtitle = $child->Title->get($lng);
  		push(@lines,"menu1.list.add('".$mtarget."','&nbsp;&nbsp;&gt;&nbsp;".$mtitle."')\n");
  		my @products = $root->get_released_children($child->Id);
  		#warn $products[0];
  		if (@products > 0) {push(@lines," tmp = new MenuList(menu1,$mcounter,widchld)\n")}
  		foreach my $product (@products) {
		    next if (!$product->is_folder);
  		    my $mtarget = "";
  		    if (defined $product->IndexDoc) { $mtarget = $product->IndexDoc };
  		    my $mtitle = $product->Title->get($lng);
  		    push(@lines,"  tmp.list.add('".$mtarget."','&nbsp;".$mtitle."')\n");
  		}
		$mcounter++;
  	    }
	    ###
	    $templatevars->{'lines'} = \@lines;
	    open (MENU, ">$outf") or error("cant writeopen $outf");
	    $t->process($c->paths->we_site_templatebase."menuconfig_tpl.js", $self->Templatevars, \*MENU ) or error("Template process failed: ", $t->error, "\n");
	    close MENU;
	}
    }
    my $outf = $c->paths->pubhtmldir."script/lookup.js";
    open (LOOKUP, ">$outf") or error("cant writeopen $outf");
    print LOOKUP 'var lookup = {';
    $self->traverselookup($objdb->root_object->Id);
    print LOOKUP " aussen:[\"12\",\"aussen\"], innen:[\"18\",\"innen\"]}";
    close LOOKUP;

    #XXX delete: $self->updatekeydb();
    #######
    # for the real menu:
    # check each objects "VisibleToMenu",
    #    if an object appears in the menu at all
    #
    # check "IndexDoc" of each folder,
    #    which page will be the index.Page of this folder
    #
    # then yo'll probably have to create the JS-file
    # "/html/nav_js/menuitems.js"
}

sub traverselookup {
    my $self = shift;

    my $root = $self->Root;
    my $objdb = $self->ObjDB;

    my $realid;
    my $targetid;
    my ($objid) = @_;
    my @children = $objdb->children($objid);
    #my @children = $root->get_released_children($objid);
    foreach my $child (@children) {
	if ($child->is_folder) {
	    if (defined $child->IndexDoc) {
		$targetid = $child->IndexDoc;
	    } elsif ($root->get_released_children($child->Id)) { 
		my @cs = $root->get_released_children($child->Id);
		if ($cs[0]) {
		    $targetid = $cs[0]->Version_Parent || "x";
		} else {
		    $targetid="x";
		}
	    } else {
		$targetid="x";
	    }
	    $realid = $child->Id;
	}
	my $chobj = $root->get_released_object($child->Id);
	if ($chobj) {
	    $realid = $chobj->Version_Parent;
	    #my $realid = $child->Id;
	    $targetid = $realid;

	}
	print LOOKUP $realid.':["'.$targetid.'.html"';
	if ($root->can("get_section")) {
	    print LOOKUP ',"' . $root->get_section($child->Id) . '"';
	}
	print LOOKUP '],'."\n";
        if ($child->is_folder) {
	    $self->traverselookup($child->Id);
	}
    }
}

sub traversemenu {
    my ($self,$objid,$lines,$lang) = @_;
    my $root = $self->Root;
    my @children = $root->get_released_children($objid);
    foreach my $child (@children) {
        if ($child->is_folder) {
	    $self->traversemenu($child->Id,$lines,$lang);
	} else {
	    push(@$lines,"<a href='html/$lang/".$child->Id.".html' target='main'>".$child->Id."</a><br>")
	}
    }
}

1;
