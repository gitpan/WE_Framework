# -*- perl -*-

#
# $Id: MainAny.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::MainAny;

use strict;
use vars qw($VERSION $VERBOSE);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

$VERBOSE = 0 if !defined $VERBOSE;

sub new {
    my($class, $root) = @_;

    my $get_wesiteinfo = sub {
	my $wesiteinfo = $INC{"WEsiteinfo.pm"};
	if (!defined $wesiteinfo) {
	    die "Strange: WEsiteinfo can be required, but is not recorded in \%INC";
	}
	if (!-r $wesiteinfo) {
	    die "Strange: WEsiteinfo can be required, but the file $wesiteinfo is not accessible";
	}
	$wesiteinfo;
    };

    # try for new implementation:
    use vars qw($c);
    require File::Spec;
    my $err;
    {
	unless ($VERBOSE) {
	    open(OLDERR, ">&STDERR");
	    open(STDERR, ">".File::Spec->devnull) or die $!;
	}
	eval 'use WEsiteinfo qw($c)';
	$err = $@;
	if ($VERBOSE && $err) {
	    warn "warn at line " . __LINE__ . ": " . $err;
	}
	unless ($VERBOSE) {
	    open(STDERR, ">&OLDERR");
	    close OLDERR;
	}
    }
    if (!$err) {
	my $wesiteinfo = $get_wesiteinfo->();
	require WE_Frontend::Main2;
	return WE_Frontend::Main->new(-root => $root, -config => $c);
    }

    # try for old implementation
    eval 'use WEsiteinfo qw($rootdir)';
    $err = $@;
    if ($VERBOSE && $err) {
	warn "warn at line " . __LINE__ . ": " . $err;
    }
    if (!$err) {
	require WE_Frontend::Main;
	return WE_Frontend::Main->new($root);
    }

    die $err;
}

1;

__END__

=head1 NAME

WE_Frontend::MainAny - find the current WEsiteinfo and Main* implementation

=head1 SYNOPSIS

    use WE_Frontend::MainAny;
    my $main = new WE_Frontend::MainAny $root;

=head1 DESCRIPTION

There is C<WE_Frontend::Main> and C<WEsiteinfo.pm> with the old
variable syntax, and on the other hand there is C<WEsiteinfo::Main2>
and C<WEsiteinfo.pm> with the new accessor syntax.
C<WE_Frontend::MainAny> tries hard to find the current implementation.

To be successful, make sure that C<WEsiteinfo.pm> is in your C<@INC>
path. The optional argument C<$root> will be passed as the
C<WE_...::Root> object to the real C<Main> or C<Main2> module.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::Main>, L<WE_Frontend::Main2>, L<WE_Frontend::Info>.

=cut

