# -*- perl -*-

#
# $Id: IndexerLive.pm,v 1.3 2005/03/13 17:33:31 cmuellermeta Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use mixin::with "WebEditor::OldController";

sub run_live_indexer {
    require File::Basename;
    require File::Spec;
    my $self = shift;
    my $c = $self->C;
    my $liveuser=$c->staging->user;

    my @cmd;
    
    unless ("$liveuser"){
	    print "creating Live Index for localhost...<br>\n";
	    @cmd = (File::Spec->catfile(File::Basename::dirname($c->staging->directory), "etc", "run_indexer"));
   
    }else{
	   print "creating Live Index for remote host...<br>\n";
    	   my @cmd = (qw(ssh -l) , $c->staging->user,
	   $c->staging->host,
	   File::Spec->catfile(File::Basename::dirname($c->staging->directory),
				   "etc", "run_indexer"),
	   );
}
    print "<pre>";
    print "Run: @cmd\n";
    system(@cmd);
    print "Exit code: $?\n";
    print "</pre>";
}

1;

__END__
