package WebEditor::OldFeatures::KeyDB;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use WE::Util::LangString qw(langstring);

######################################################################
#
# updating keyword database
#
sub updatekeydb {
    my $self = shift;

    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $c = $self->C;

    my ($folder_id) = 0;
    my %keywords;
    my %id2title;

    foreach my $lang (@{ $c->project->sitelanguages }) {
# "Walk" through every object
    $objdb->walk($folder_id, sub {
        my ($id) = @_;
        my $obj = $objdb->get_object($id);
        # Check if object is released
	#print "<br>$id : ";
        if ($obj->Release_State eq 'released' && $obj->Keywords) {
	    #print "ok";
            #warn $obj->Id;
            foreach my $word ( split(/,/, langstring($obj->Keywords, $lang) ) ) {
		#nur als Kleinbuchstaben speichern
                $keywords{lc($word)} .= $obj->Id.",";
		my $title = $obj->Title->{$lang};
		if ($root->can("get_section")) {
		    $title .= "|".$root->get_section($obj->Id);
		}
		$id2title{$obj->Id} = $title;
                #print $word." " if ($debug);
            }
        }
    });

# Write keywords to file
    my $file = $c->paths->pubhtmldir."/html/keywords_".$lang.".dat";
    open (SEARCH, ">$file")
        or error( "can't writeopen keyworddb $file");
    foreach my $key (sort keys %keywords) {
        print SEARCH "$key|".$keywords{$key}."\n";
    }
    print SEARCH ">>> Id to title\n";
    foreach my $id (sort keys %id2title) {
        print SEARCH "$id=".$id2title{$id}."\n";
    }
    close SEARCH;
    #print "<br>Keywords-Datei $file gespichert.\n";

    }
}

1;
