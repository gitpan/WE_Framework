# -*- perl -*-

#
# $Id: IxHash.pm,v 1.2 2003/01/16 14:29:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Content::IxHash;

use strict;
use vars qw($VERSION @ISA @EXPORT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Exporter;
use Tie::IxHash;
@ISA = qw(Exporter Tie::IxHash);

@EXPORT = qw(OH);

sub OH {
    tie my %h, 'WE_Content::IxHash', @_;
    bless \%h, 'WE_Content::IxHashRef';
}

sub DD_new {
    my($self, $name) = @_;
    Data::Dumper->new([$self], [$name])
	->Toaster('thaw')
	->Freezer('freeze')
	->Useperl(0)
}

package WE_Content::IxHashRef;

# for Data::Dumper::Freezer
sub freeze {
    my $ixhashref = shift;
    bless [
        %$ixhashref
    ], 'WE_Content::IxHashRef::ZZZ';
}

package WE_Content::IxHashRef::ZZZ;

# for Data::Dumper::Toaster
sub thaw {
    my $ixhashrefzzz = shift;
    WE_Content::IxHash::OH(@$ixhashrefzzz);
}

# XXX eventually override Storable and/or Data::Dumper freeze/thaw methods?

1;

__END__

=head1 NAME

WE_Content::IxHash - provide ordered hashes

=head1 SYNOPSIS

    $hashref = OH(key => val, key => val, ...)

=head1 DESCRIPTION

The only exported function is C<OH>, which takes a list of keys
and values and returns a reference to an ordered hash.

=head1 REQUIREMENTS

C<WE_Content::IxHash> is based on C<Tie::IxHash>.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 2002 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
