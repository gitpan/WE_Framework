package WebEditor::OldFeatures::AdminHtdig;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

use CGI qw(param);

sub mapping {
    ("htdig" => "admin_htdig_module")
}

sub admin_htdig_module {
    my($self, %args) = @_;

    while(my($k,$v) = each %args) {
	param(substr($k,1), $v);
    }

    if (param('host') eq 'live' &&
	$self->can("run_live_indexer")) {
	return $self->run_live_indexer;
    }

    my $c = $self->C;

    require WE_Frontend::Indexer::Htdig;

    local $| = 1;

    print <<EOF;
<script>
if (top.mainpanel && top.mainpanel.setwait) {
    top.mainpanel.setwait(1, 'erstelle Suchindex...');
}
</script>
EOF

    # refresh htdig-index
    my $conf;
    if (param('host') eq 'live') {
	$c = $c->liveconfig;
	$conf = $c->searchengine->htdigconf;
    } elsif (param('host') =~ /^(prelive|local)$/) {
	$conf = $c->searchengine->htdigconf;
    }

    my $logfile = "/tmp/htdig_debug." . $< . ".log";
    unlink $logfile;
    for my $lang (@{ $c->project->sitelanguages }) {
	print $self->_html_method("Erstelle Suchindex für die Sprache $lang") . "<br>\n"; # XXX lang etc.
	{
	    my $conf = WE_Frontend::Indexer::Htdig::generate_conf
		($c, -htdigconf => $conf, -lang => $lang, -debug => 1);
	    my $silent = " >>$logfile 2>&1";
	    #		my $silent = "";
	    # XXX -c is always necessary?
	    my $cmd = $c->searchengine->searchindexer . $silent . " -c " . $conf;
	    print "Kommando: $cmd<br>\n";
	    my $err = system $cmd;
	    die "Fehler beim Kommando $cmd: $!" if $err;
	}
	if (!WE_Frontend::Indexer::Htdig::conf_is_lang_dependent($conf)) {
	    print $self->_html_method("Die Suchkonfiguration $conf gilt für alle weiteren Sprachen") . "<br>\n";
	    last;
	}
    }
    print "\n\n<br><br> - fertig!<br><hr><br>";
    print "<script>top.mainpanel.setwait(0);</script>";
}

1;
