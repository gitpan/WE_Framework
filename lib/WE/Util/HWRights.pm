# -*- perl -*-

#
# $Id: HWRights.pm,v 1.4 2004/02/03 15:07:42 eserte Exp $
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

package WE::Util::HWRights;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

die "This is work in progres... use WE::Util::SimpleRights instead...!";

sub new {
    my($class, $rightstring) = @_;
    bless \$rightstring, $class;
}

# XXX check the HW semantics if there are missing right bits
sub parse {
    my($class, $rightstring) = @_;

    if (!defined $rightstring || $rightstring =~ /^\s*$/) {
	return {'R' => ['a','o'], 'U' => ['a'], 'W' => ['a']};
    }

    my $rights = {'R' => 'o', 'U' => ['a'], 'W' => ['a']};
    foreach (split /\s*;\s*/, $rightstring) {
	if (!/^([RWU]):(.*)$/) {
	    die "Invalid right string component $_";
	}
	my($action, $entities) = ($1, $2);
	foreach (split /\s*,\s*/, $entities) {
	    if (!/^(?:(a)|([ug])\s+(.*))$/) {
		die "Invalid right string component $_";
	    }
	    if ($1 eq 'a') {
		push @{$rights->{$action}}, 'a';
	    } else {
		my($entity_group, $entities) = ($1, $2);
		foreach (split /\s+/, $entities) {
		    push @{$rights->{$action}}, "$entity_group $_";
		}
	    }
	}
    }
}

1;

__END__

=head1 NAME

WE::Util::HWRights - a permission model just like the H*perW*ve model

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

