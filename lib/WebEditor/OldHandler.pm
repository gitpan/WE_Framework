# -*- perl -*-

#
# $Id: OldHandler.pm,v 1.4 2004/04/16 23:27:35 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldHandler;

use strict;
no strict 'refs';
use vars qw($VERSION %config);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use Apache;

sub handler ($$) {
    my($self, $r) = @_;

    my $c = $self->get_wesiteinfo_config($r);
    my $oc = $self->get_controller_object($c);

    local $SIG{__DIE__} = $oc->get_die_handler;
    $oc->handle($c, $r);
}

sub get_wesiteinfo_config {
    my($self, $r) = @_;
    my $wesiteinfo_file  = $r->dir_config("wesiteinfo_file");
    my $wesiteinfo_class = $r->dir_config("wesiteinfo_class");
    my $c = $config{$wesiteinfo_class};
    if (!$c) {
	if (!defined $wesiteinfo_file) {
	    $wesiteinfo_file = $wesiteinfo_class;
	}
	require $wesiteinfo_file;
	$c = $wesiteinfo_class->get_config;
	$config{$wesiteinfo_class} = $c;
    }
    $c;
}

sub get_controller_object {
    my($self, $c) = @_;
    my $controller_class = "WE_" . $c->project->name . "::OldController";
    eval q{use } . $controller_class;
    if ($@) {
	if ($@ =~ /Can't locate/) {
	    # use generic controller instead
	    $controller_class = "WebEditor::OldController";
	    eval q{ use } . $controller_class;
	    die $@ if $@;
	} else {
	    die $@;
	}
    }
    my $oc = $controller_class->new;
    $oc;
}

1;

__END__
