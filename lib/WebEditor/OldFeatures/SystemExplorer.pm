# -*- perl -*-

#
# $Id: SystemExplorer.pm,v 1.1 2004/04/01 17:08:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sourceforge.net/projects/we-framework
#

package WebEditor::OldFeatures::SystemExplorer;

=head1 NAME

WebEditor::OldFeatures::SystemExplorer -

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Slaven Rezic.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

sub WebEditor_SystemExplorer_Class { "WebEditor::SystemExplorer" }

sub systemexplorer {
    my $self = shift;
    $self->identify;
    my $root = $self->Root;
    if (!$root->is_allowed(["admin"])) {
	die "This function is only allowed for users with admin rights\n";
    }
    eval qq{ require } . $self->WebEditor_SystemExplorer_Class;
    die $@ if $@;
    my $se = $self->WebEditor_SystemExplorer_Class->new($self);
    $se->dispatch;
}

1;
