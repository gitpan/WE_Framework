# -*- perl -*-

#
# $Id: Htgroup.pm,v 1.5 2004/04/02 10:32:50 eserte Exp $
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

package WE::Util::Htgroup;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE::Util::Htgroup - create apache AuthGroupFile files from a user database

=head1 SYNOPSIS

    use WE::Util::Htgroup;
    WE::Util::Htgroup::create("/var/www/.group", $complex_user_db);

=head1 DESCRIPTION

Create apache AuthGroupFile files from a WE_Framework user database.

=head2 FUNCTIONS

=over 4

=item create($dest_file, $user_db, %args);

Create the C<$dest_file> from the (complex) user database object
C<$user_db>.

=cut

sub create {
    my($dest_file, $user_db, %args) = @_;
    my %groups;
    foreach my $uid ($user_db->get_all_users) {
	my(@groups) = $user_db->get_groups($uid);
	foreach my $group (@groups) {
	    push @{ $groups{$group} }, $uid;
	}
    }
    open(GROUP, ">$dest_file") or die "Can't write to $dest_file: $!";
    while(my($group, $members) = each %groups) {
	print GROUP "$group: " . join(" ", @$members) . "\n";
    }
    close GROUP;
    1;
}

=item invalid_chars

Return a string of invalid characters for group names. This is handy
for using in C<ComplexUser>:

    new WE::DB::ComplexUser(..., ...,
                            -crypt => "none",
                            -invalidchars => WE::Util::Htpasswd::invalid_chars(),
                            -invalidgroupchars => WE::Util::Htgroup::invalid_chars())

=cut

sub invalid_chars {
    ": ";
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<htpasswd(1)>, L<WE::DB::ComplexUser>, L<WE::Util::Htaccess>, L<WE::Util::Htpasswd>.


=cut

