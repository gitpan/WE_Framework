# -*- perl -*-

#
# $Id: GenericTree.pm,v 1.4 2004/02/02 08:11:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (c) 1995-2000 Slaven Rezic. All rights reserved.
# Copyright (C) 2000,2002 Online Office Berlin. All rights reserved.
# Copyright (c) 2002,2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#
# This is derived from Timex::Project.
#

package WE::Util::GenericTree;

=head1 NAME

WE::Util::GenericTree - generic class for tree representations

=head1 SYNOPSIS

    $tree = new WE::Util::GenericTree $data

=head1 DESCRIPTION

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use fields qw(Data Id Subtrees Parent Modified Separator);

=head2 new

    $tree = new WE::Util::GenericTree $data

Construct a new GenericTree object with content $data.

=cut

sub new {
    my WE::Util::GenericTree $self;

    if ($] < 5.006) {
	my $class = shift;
	no strict 'refs';
	$self = bless [\%{"$class\::FIELDS"}], $class;
    } else {
	$self = shift;
	$self = fields::new($self) unless ref $self;
    }

    my $data = shift;
    $self->data($data);

    $self->{Subtrees}  = [];
    $self->{Parent}    = undef;
    $self->{Modified}  = 0;
    $self->{Separator} = "/";

    $self;
}

sub maybe_construct {
    my $self = shift;
    my $obj = shift;
    if (UNIVERSAL::isa($obj, __PACKAGE__)) {
	$obj;
    } else {
	$self->new($obj);
    }
}

sub data {
    my $self = shift;

    if (@_) {
	my $data = shift;

	$self->{Data}     = $data;
	if (ref $data && UNIVERSAL::can($data,"id")) {
	    $self->{Id}   = $data->id;
	} elsif (ref $data && UNIVERSAL::isa($data, "HASH") && exists $data->{Id}) {
	    $self->{Id}   = $data->{Id};
	} elsif (defined $data) {
	    $self->{Id}   = $data;
	} else {
	    die "No id found";
	}
    }

    $self->{Data};
}

sub id { $_[0]->{Id} }

# XXX setting of parent is not used for external use ...
# use subtree (for the other direction) instead
sub parent {
    my($self, $parent) = @_;
    if (defined $parent) {
	$self->{Parent} = $parent;
	$self->modified(1);
    } else {
	$self->{Parent};
    }
}

=head2 reparent

    $tree->reparent($newparent)

Use this method only if there is already a parent. Otherwise, use the
parent method.

=cut

sub reparent {
    my($self, $newparent) = @_;
    my $oldparent = $self->parent;
    # don't become a child of a descended tree :-)
    return if $self->is_descendent($newparent);
    return if !$oldparent;         # don't reparent root
    $oldparent->delete_subtree($self);
    $newparent->subtree($self);
}

=head2 root

    $root = $tree->root;

Return root node of the given $tree.

=cut

sub root {
    my $self = shift;
    if ($self->parent) {
	$self->parent->root;
    } else {
	$self;
    }
}

=head2 modified

    $modfied = $tree->modified

Return true if the tree is modified, that is, one of root's #'
subtrees are modified.

    $tree->modified($modified)

Set the modified attribute (0 or 1) for the root tree.

=cut

sub modified {
    my($self, $flag) = @_;
    my $root = $self->root;
    if (defined $flag) {
	$root->{Modified} = ($flag ? 1 : 0);
    } else {
	$root->{Modified};
    }
}

=head2 subtree

    $root->subtree([$tree1, ...]);

With a $tree defined, put the trees as subtrees of $root. Without
$tree, return either an array of subtrees (in array context) or a
reference to the array of subtrees (in scalar context).

The argument can be either GenericTree objects or another scalars, in
which case they will be used as the data argument to the constructor
of GenericTree.

Alias: children.

=cut

sub subtree {
    my $self = shift;
    if (@_) {
	my @res;
	my $class = ref $self;
	foreach my $subtree (@_) {
	    my WE::Util::GenericTree $sub;
	    if (ref $subtree && UNIVERSAL::isa($subtree, __PACKAGE__)) {
		$sub = $subtree;
	    } else {
		$sub = $class->new($subtree);
	    }
	    $sub->parent($self);
	    push @{ $self->{Subtrees} }, $sub;
	    $self->modified(1);
	    push @res, $sub;
	}
	wantarray ? @res : $res[0];
    } else {
	wantarray ? @{ $self->{Subtrees} } : $self->{Subtrees};
    }
}

*children = \&subtree;

sub is_descendent {
    my($self, $tree) = @_;
    return 1 if $self eq $tree;
    foreach ($self->subtree) {
	my $r = $_->is_descendent($tree);
	return 1 if $r;
    }
    0;
}

sub delete_subtree {
    my($self, $subp) = @_;
    my @subtrees = $self->subtree;
    my @newsubtrees;
    foreach (@subtrees) {
	push @newsubtrees, $_ unless $_ eq $subp;
    }
    $self->{Subtrees} = \@newsubtrees;
    $self->modified(1);
}

=head2 find_by_pathname

    $tree = $root->find_by_pathname($pathname);

Search and return the corresponding $tree (or undef if no such
tree exists) for the given $pathname.

=cut

sub find_by_pathname {
    my($self, $pathname) = @_;
    return $self if $self->pathname eq $pathname;
    foreach ($self->subtree) {
	my $r = $_->find_by_pathname($pathname);
	return $r if defined $r;
    }
    return undef;
}

sub pathname { # virtual pathname!
    my($self, $separator) = @_;
    $separator = $self->separator if !defined $separator;
    my @path = $self->path;
    if (!defined $path[0] || $path[0] eq '') {
	shift @path;
    }
    join($separator, @path);
}

sub path {
    my($self) = @_;
    my @path;
    if (!defined $self->parent) {
	@path = ($self->id);
    } else {
	@path = ($self->parent->path, $self->id);
    }
    wantarray ? @path : \@path;
}

=head2 separator

    $separator = $tree->separator

Return the separator for this tree. Defaults to /.

    $project->separator($separator);

Set the separator for this tree to $separator.

=cut

sub separator {
    my($self, $separator) = @_;
    my $root = $self->root;
    if (defined $separator) {
	$root->{Separator} = $separator;
    } else {
	$root->{Separator};
    }
}

sub level {
    my $self = shift;
    if (!defined $self->{Parent}) {
	0;
    } else {
	$self->{Parent}->level + 1;
    }
}

sub insert_tree {
    my($self, $obj, $type, $pathname) = @_;
    my $tree = $self->find_by_pathname($pathname);
    if (defined $tree) {
	if ($type eq '-below') {
	    $tree->subtree($obj);
	} else {
	    my $parent = $tree->parent;
	    die "Can't find parent for $tree" unless $parent;

	    my $i = 0;
	SEARCH: {
		foreach my $sub (@{ $parent->{Subtrees} }) {
		    if ($sub eq $tree) {
			last SEARCH;
		    }
		    $i++;
		}
		die "Fatal: $tree not found in $parent";
	    }

	    my $new_obj = $self->maybe_construct($obj);

	    if      ($type eq '-at') {
		$parent->{Subtrees}[$i] = $new_obj;
	    } elsif ($type eq '-after') {
		splice @{ $parent->{Subtrees} }, $i, 0, $new_obj;
	    } elsif ($type eq '-before') {
		splice @{ $parent->{Subtrees} }, $i-1, 0, $new_obj;
	    } else {
		die "Invalid type $type";
	    }
	}
    } else {
	die "Can't find pathname $pathname";
    }
}

1;

__END__

=head1 HISTORY

This module before version 1.04 had the misnamed undocumented method
B<eventually_construct> which is renamed to C<maybe_construct>.

=head1 COPYRIGHT

Copyright (c) 1995-2000 Slaven Rezic. All rights reserved.
Copyright (C) 2000,2002 Online Office Berlin. All rights reserved.
Copyright (c) 2002,2004 Slaven Rezic. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
