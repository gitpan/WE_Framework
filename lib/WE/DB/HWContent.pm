# -*- perl -*-

#
# $Id: HWContent.pm,v 1.3 2003/01/16 14:29:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::HWContent;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, $root) = @_;
    my $self = {Root => $root};
    bless $self, $class;
}

sub store {
    my($self, $obj, $content) = @_;
    die "NYI";
}

sub get_content {
    my($self, $obj) = @_;
    # XXX diff between HTML and text
    $self->{Root}->ObjDB->HW->get_text($obj->Id);
}

1;

__END__

=head1 NAME

WE::DB::HWContent - interface to hyperwave content

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

