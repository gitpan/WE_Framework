package WebEditor::OldFeatures::XMenus;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);
use base qw(Exporter);

@EXPORT = qw(makemenu makemenu_string); # mixin

use CGI qw(param);
use HTML::Entities ();

use WE::Util::LangString qw(langstring);

######################################################################
#
# create the menu
#
sub makemenu_string {
    my $self = shift;
    my %args = @_;

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;

    my $root_id = $args{startid};
    $root_id = $objdb->root_object->Id if !defined $args{startid};
    my $lang = $args{lang} || $c->project->sitelanguages->[0];

    my $out = "";
    my $indent = 0;
    my %ul_done;

    # XXX maybe use ::prune instead?
    my $is_visible = sub {
	my $obj = shift;
	my @pathobj = $objdb->pathobjects($obj);
	shift @pathobj; # ignore site object
	for my $o (@pathobj) {
	    return 0 if ($o->is_folder && !$o->{VisibleToMenu});
	}
	1;
    };

    my $handle_pre = sub {
	my($objid) = @_;
	my $obj = $objdb->get_object($objid);
	return if !$is_visible->($obj);
	my($depth) = $objdb->depth($obj);
	if ($obj->is_folder) {
	    if ($depth >= 2) {
		my $indexdoc = $obj->IndexDoc;
		my $href;
		# XXX Better use WE_Navigation::Object::relurl logic
		# here???
		if (!defined $indexdoc || $indexdoc eq "") {
		    my @children = $objdb->get_released_children($objid);
		    if (@children) {
			$indexdoc = $children[0]->Id;
		    }
		}
		if (defined $indexdoc) {
		    $href = $indexdoc . "." . get_ext($self, $indexdoc);
		}
		$out .= " "x$indent .
		    "<li>" . (defined $href ? "<a class='myBoxLblA' id='myBoxLblA_$indexdoc' href='$href'>" : "") .
			HTML::Entities::encode(langstring($obj->Title, $lang)) .
				(defined $href ? "</a>" : "") . "\n";
	    }
	    $indent++;
	} else {
	    my $fldr_depth = $depth-1;
	    if (!$ul_done{$fldr_depth}) {
		$out .= " "x($indent-1) . "<ul";
		if ($fldr_depth < 2) {
		    $out .= " id='myMenu1' class='myBar'";
		} else {
		    $out .= " class='myBox'";
		}
		$out .= ">\n";
		if ($fldr_depth == 1 && $args{homelink}) {
		    # XXX do not hardcode name, label and extension!
		    $out .= " <li><a class='myBoxLblA' href='home.html'>Home</a></li>\n";
		}
		$ul_done{$fldr_depth}++;
	    }

	    if ($depth >= 3) {
		$out .= " "x$indent .
		    "<li><a class='myItem' id='myItem_$objid' href='$objid." . get_ext($self, $objid) . "'>" .
			HTML::Entities::encode(langstring($obj->Title, $lang)) .
				"</a></li>\n";
	    }
	}
    };

    my $handle_post = sub {
	my($objid) = @_;
	my $obj = $objdb->get_object($objid);
	return if !$is_visible->($obj);
	if ($obj->is_folder) {
	    my($depth) = $objdb->depth($obj);
	    $indent--;
	    if ($ul_done{$depth}) {
		$out .= " "x$indent . "</ul>";
		delete $ul_done{$depth};
	    }
	    if ($depth >= 2) {
		$out .= "</li>";
	    }
	    $out .= "\n";
	}
    };

    $objdb->walk_prepostorder($root_id, $handle_pre, $handle_post);

    $out;
}

sub makemenu {
    my $self = shift;

    my $c     = $self->C;
    my %args;
    if ($c->project->projectext && $c->project->projectext->{xmenus}) {
	%args = %{ $c->project->projectext->{xmenus} };
    }

    for my $lang (@{ $c->project->sitelanguages }) {
	$args{lang} = $lang;
	my $out = $self->makemenu_string(%args);
	my $menufile = $c->paths->pubhtmldir . "/html/$lang/_menu.html";
	open(OUT, ">$menufile") or die "Can't write $menufile: $!";
	print OUT $out;
	close OUT;
    }
}

# Hack to get extension by object id. There should be a better means,
# e.g. storing the extension into the object or so.
sub get_ext {
    my($self, $objid) = @_;
    my $c = $self->C;
    my $lang = $c->project->sitelanguages->[0];
    my $rootdir = $c->paths->rootdir . "/html/$lang/";
    my @files = glob("$rootdir/$objid.*");
    for my $f (@files) {
	if ($f =~ m{/$objid\.(.*?)$}) {
	    return $1;
	}
    }
    return "html"; # fallback
}

1;
