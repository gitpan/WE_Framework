# -*- perl -*-

#
# $Id: IndexerLive.pm,v 1.1 2004/04/16 23:27:25 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldFeatures::IndexerLive;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with "WebEditor::OldController";

sub run_live_indexer {
    my $self = shift;
    my $c = $self->C;
    my @cmd = (qw(ssh -l) , $c->staging->user,
	       $c->staging->host,
	       File::Spec->catfile(File::Basename::dirname($c->staging->directory),
				   "etc", "run_indexer"),
	      );
    print "<pre>";
    print "Run: @cmd\n";
    system(@cmd);
    print "Exit code: $?\n";
    print "</pre>";
}

1;

__END__
