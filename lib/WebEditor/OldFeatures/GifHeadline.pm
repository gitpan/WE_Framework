package WebEditor::OldFeatures::GifHeadline;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use CGI qw(param);

######################################################################
#
# trigger gif-engine and cretae a gif-headline
#
sub gifheadline {
    my $self = shift;
    my %args = @_;
    my $bgcolor = $args{bgcolor};
    my $pageid  = $args{pageid};
    my $hl_lang = param('hllanguage') || $args{lang};
    my $gh = $self->{GifHeadline}; # XXX
    if(!$bgcolor) { $bgcolor="ffffff"; }
    my $headlinefile = $gh->{headlinedir}."hl_".$pageid."_".$hl_lang.".gif";
    my $text = param('createheadline');
    warn "gifheadlinetext: $text";
    my $gifengine = $gh->{gifengine};
    my $out = `$gifengine -o$headlinefile -s18 -c000000 -b$bgcolor '$text'`;
    $out =~ /Width=(\d+)\nHeight=(\d+)/;
    my $w = $1;
    my $h = $2;
    $self->Templatevars->{'hlgif'} = "hl_".$pageid."_".$hl_lang.".gif";
    $self->Templatevars->{'hltext'} = $text;
}

1;
