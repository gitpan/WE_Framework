# -*- perl -*-

#
# $Id: FromString.pm,v 1.3 2003/01/16 14:29:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Onlineoffice. All rights reserved.
# Copyright (c) 2002 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Util::GenericTree::FromString;

=head1 NAME

GenericTree::FromString - creating GenericTrees from a string representation

=head1 SYNOPSIS

    my $tree = new GenericTree::FromString <<EOF;
    A
     AA
     AB
     AC
      ACA
      ACB
     AD
     AE
    B
    C
     CA
    EOF
    $tree->isa("GenericTree"); # yes

=head1 DESCRIPTION

=cut

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
# use base does not work for 5.005?
use WE::Util::GenericTree;
push @ISA, 'WE::Util::GenericTree';

sub new {
    my $proto = shift;
    my $string_rep = shift;
    my $class = ref($proto) || $proto;

    my $root = my $tree = new WE::Util::GenericTree {Id => ""}; # root
    my $last_level = -1;
    foreach my $line (split /\n/, $string_rep) {
	$line =~ /^(\s*)(.*)/;
	my $level = defined $1 ? length $1 : 0;
	my $value = $2;
	if ($level > $last_level+1) {
	    die "Too big jump from level $last_level to level $level in line $line";
	} elsif ($level == $last_level+1) {
	    my $subtree = $tree->subtree($value);
	    $last_level++;
	    $tree = $subtree;
	} elsif ($level == $last_level) {
	    $tree = $tree->parent->subtree($value);
	} else {
	    #warn "$level .. $last_level $value";
	    for ($level .. $last_level-1) {
		$tree = $tree->parent;
		$last_level--;
	    }
	    $tree = $tree->parent->subtree($value);
	}
    }

    bless $root, $class;
}

1;

__END__

=cut
