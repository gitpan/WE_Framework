package WebEditor::OldFeatures::TeaserLink;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use CGI qw(param);

use Data::JavaScript;

sub showeditor_teaserlink {
    my $self = shift;
    my $root = $self->Root;
    $self->login
	unless $root->identify($self->User,$self->Password);
    my $objdb = $root->ObjDB;

    my $lg = param('language');
    my $teaserfolderid = $objdb->name_to_objid('teaser');
    my @teaserpageids = $objdb->children_ids($teaserfolderid);
    # how many teaserpages are there in the "teaser"-folder?
    my @pageids;
    my @titles;
    my @pages;
    foreach my $teaserpageid (@teaserpageids) {
	my @teaserarray;
	my @teasers;
	use vars qw($outdata);
	eval( $objdb->content($teaserpageid) );
	@teaserarray = eval { @{$outdata->{data}->{$lg}->{ct}[0]{ct}} };
	warn "Problem for lang=$lg, teaserpageid=$teaserpageid: $@" if $@;
	# get all teasers of this page
	my $counter = 0;
	foreach my $tsr (@teaserarray) {
	    # get this teasers headline
	    push(@teasers, $tsr->{ct}[0]->{text});
	}
	push(@pages,{headlines => \@teasers,
		     pageid => $teaserpageid,
		     pagetitle => $outdata->{data}->{$lg}->{title} });
    }
    my $jscode = Data::JavaScript::jsdump('teaserhl',\@pages);
    $self->_tpl("bestwe", "we_teaserlinker.tpl.html",
		{ 'js' => $jscode });
}

1;

=head1 NAME

WebEditor::OldFeatures::TeaserLink - feature to add teasers to pages

=head1 SYNOPSIS

Add this to your WE_I<projectname>::OldController:

    use WebEditor::OldFeatures::TeaserLink;
    *showeditor_teaserlink = \&WebEditor::OldFeatures::TeaserLink::showeditor_teaserlink;

=head1 AUTHOR

Slaven Rezic

=cut
