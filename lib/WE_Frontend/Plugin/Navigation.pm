# -*- perl -*-

#
# $Id: Navigation.pm,v 1.20 2004/03/25 11:56:24 eserte Exp $
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

package WE_Frontend::Plugin::Navigation;
use base qw(Template::Plugin);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

require WE_Frontend::Plugin::Navigation::Object;

=head1 NAME

WE_Frontend::Plugin::Navigation - utilities for navigation creation

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE Navigation %]

=head1 DESCRIPTION

C<WE_Frontend::Plugin::Navigation> is a C<Template-Toolkit> plugin to
make the creation of navigations based on objects in a C<WE::DB::Obj>
database easier. The C<WE_Frontend::Plugin::Navigation> object
corresponds somewhat to the C<WE::DB::Obj> database. Most of the
methods described below return
L<WE_Frontend::Plugin::Navigation::Object> objects, which correspond
to L<WE::Obj> objects.

=head2 METHODS

=over

=item new

This method is normally not called directly, but only as part of the
C<USE> directive:

    [% USE Navigation %]
    [% USE n = Navigation %]

You can pass the named parameter C<objid> to set the object id for
this context.

    [% USE n = Navigation(objid = 10) %]

Or you can use the C<name> parameter:

    [% USE n = Navigation(name = "rootcollection") %]

You can pass the named parameter C<objid> to set the object id for
this context.

When calling the process() method of C<Template-Toolkit> the value for
C<objdb> (a reference to the L<WE::DB::Obj> database) should be set or
C<rootdb> (a reference to the L<WE::DB> database) XXX rootdb prefered if content access.
Also, if C<objid> is not set in the C<USE> directive, it may be
supplied to the process() method.

    my $t = Template->new(
        {PLUGIN_BASE => "WE_Frontend::Plugin"}
    );
    $t->process(
        \$template,
        {
         objdb      => $objdb,
	 rootdb     => $rootdb,
         objid      => $objid,
         config     => $c,
         langstring => \&WE::Util::LangString::langstring
        },
        \$output
    );

The return value of the C<USE Navigation> directive (the C<n> variable
in the examples above) is a L<WE_Frontend::Plugin::Navigation::Object>
of the current object supplied with the C<objid> key.

=cut

sub new {
    my($class, $context, $params) = @_;
    $params ||= {};
    my $rootdb = $params->{rootdb} || eval { $context->stash->get("rootdb") };
    my $objdb = $params->{objdb} || eval { $context->stash->get("objdb") };
    if (!$objdb && $rootdb) {
	$objdb = $rootdb->ObjDB;
    }
    if (!$objdb) {
	if ($rootdb) {
	    return $class->error("The required parameter rootdb is defined, but its member ObjDB is not defined");
	} else {
	    return $class->error("The required parameter objdb and/or rootdb is not defined");
	}
    }
    my $objid = $params->{objid};
    if (!defined $objid) {
	if (defined $params->{name}) {
	    $objid = $objdb->name_to_objid($params->{name});
	}
    }
    if (!defined $objid) {
	$objid = eval { $context->stash->get("objid") };
    }
    my $self = {
		Context => $context,
		RootDB => $rootdb,
		ObjDB => $objdb,
		ObjID => $objid,
		POCache => {}, # for pathobjects_with_cache
	       };
    bless $self, $class;
}

=item ancestors([[objid = id | name = name], fromlevel => level, tolevel => level, restrict = restrictmethod])

Return a list of ancestors of the current object. The oldest
(top-most) ancestor is first in the list. If C<objid> is given, then
return the ancestors for the object with this object identifier. If
C<fromlevel> and/or C<tolevel> are given, then restrict the ancestor
list for these levels. The topmost level is numbered with 1. The root
itself is numbered with 0, this can be used for a "home" link on top
of the list. The list may be restricted by specifying C<restrict>. If
tolevel is less than fromlevel, then an empty list is returned.

=cut

sub ancestors {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my @l = $self->{ObjDB}->pathobjects_with_cache($self->current_id($params), undef, $self->{POCache});
    pop @l; # delete last in list (the object itself);
    $self->objify_list(\@l);

    if (defined $params->{fromlevel}) {
	if (defined $params->{tolevel}) {
	    @l = @l[$params->{fromlevel} .. $params->{tolevel}];
	} else {
	    @l = @l[$params->{fromlevel} .. $#l];
	}
    } elsif (defined $params->{tolevel}) {
	@l = @l[0 .. $params->{tolevel}];
    }

    $self->restrict($params, \@l);
    [@l];
}

=item parent([[objid = id | name = name]])

Return the parent of the current object, or of the object with id
C<objid>. Note that it is possible in the C<WE::DB::Obj> database to
have more than one parent, nevertheless only one parent is returned.

=cut

sub parent {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $obj = $self->current_object($params);
    my $objdb = $self->{ObjDB};
    my(@l) = ($objdb->parents($obj))[0];
    $self->objify_list(\@l);
    $self->restrict($params, \@l);
    $l[0];
}

=item level([[objid = id | name = name]])

Return the level of the current object, or of the object with id
C<objid>. The root of the site has level = 0.

=cut

sub level {
    my $self = shift;
    scalar @{ $self->ancestors(@_) };
}

=item toplevel_children([sort = sortmethod, restrict = restrictmethod])

Return a list of sorted toplevel children. Normally, the sequence
order is used but the sorting can be changed by specifying C<sort>.
The list may be restricted by specifying C<restrict>.

=cut

sub toplevel_children {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    $params->{'level'} = 1;
    $self->siblings($params);
}

=item siblings([[objid = id | name = name], level = level, sort = sortmethod, restrict => restrictmethod])

Get the siblings of the current object, or of the object with id
C<objid>. The siblings are sorted by the sortmethod in C<sort> and
can be restricted with C<restrict>.

If C<level> is specified, the siblings of the ancestor of the current
object in the specified level are returned. The level can also be
specified as a negative number; this means how many levels up from the
current position should be used.

=cut

sub siblings {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $objid = $self->current_id($params);
    my $objdb = $self->{ObjDB};
    my $pid;
    my @l;
    if (defined $params->{level}) {
	my @ancestors = $objdb->pathobjects_with_cache($objid, undef, $self->{POCache});
	if ($params->{level} =~ /^\d/) {
	    $pid = $ancestors[$params->{level}-1]; # XXX -1 ???
	} elsif ($params->{level} =~ /^-(\d+)$/) {
            if (-($params->{level}-2) > scalar @ancestors + 1) {
		return $self->error("Level above root object");
	    } elsif (-($params->{level}-2) == scalar @ancestors + 1) {
		# the root object itself
		@l = $ancestors[0];
		$self->objify_list(\@l);
		$self->restrict($params, \@l);
		# no sorting necessary :-)
		return @l;
	    } else {
		$pid = $ancestors[$params->{level}-2]
	    }
	} else {
	    return $self->error("Invalid level specifier: $params->{level}");
	}
    } else {
	$pid = ($objdb->parent_ids($objid))[0];
    }
    @l = $objdb->children($pid);
    $self->objify_list(\@l);
    $self->restrict($params, \@l);
    $self->sort($params, \@l);
    [@l];
}

=item children([[objid = id | name = name], sort = sortmethod, restrict => restrictmethod])

Get the children of the current object, or of the object with id
C<objid>. The children are sorted by the sortmethod in C<sort> and
can be restricted with C<restrict>.

=cut

sub children {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $obj = $self->current_object($params);
    my @l = $self->{ObjDB}->children($obj);
    $self->objify_list(\@l);
    $self->restrict($params, \@l);
    $self->sort($params, \@l);
    [@l];
}

=item siblings_or_children([...]);

Often, siblings are used if the object is a document and children are
used if the object is a folder. This convenience method uses the
appropriate method. The arguments are the same as in C<siblings> or
C<children>.

=cut

sub siblings_or_children {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $obj = $self->current_object($params);
    if ($obj->is_doc) {
	$self->siblings($params);
    } else {
	$self->children($params);
    }
}

=item restrict($params, $listref)

Internal method to restrict the passed array reference according to
the C<<$params->{restrict}>> subroutine.

The value of the C<restrict> parameter should be the name of a method
in the C<WE_Frontend::Plugin::Navigation::Object> class. The object is
accepted if the returned value is true. Example for an user-defined
method (although subclassing would be the cleaner solution):

    package WE_Frontend::Plugin::Navigation::Object;
    sub my_restrict {
        my $o = shift;
        # restrict to objects with Id less than 5
        $o->o->Id < 5;
    }

=cut

sub restrict {
    my($self, $params, $listref) = @_;
    my $sub = $params->{restrict};
    return if !$sub || !@$listref;
    @$listref = grep { $_->$sub() } @$listref;
}

=item sort($params, $listref)

Internal method to sort the passed array reference according to
the C<<$params->{sort}>> subroutine.

The value of the C<sort> parameter should be the name of a method in
the C<WE_Frontend::Plugin::Navigation> class. This method takes to
arguments C<$a> and C<$b>, both
C<WE_Frontend::Plugin::Navigation::Object> objects which should be
compared. The returned value should be -1, 0, or 1, just as in the
C<sort> function. Example for an user-defined method (although
subclassing would be the cleaner solution):

    package WE_Frontend::Plugin::Navigation;
    sub my_sort {
        my($self, $a, $b) = @_;
        # sort by title
        WE::Util::LangString::langstring($a->o->Title) cmp WE::Util::LangString::langstring($b->o->Title);
    }

=cut

sub sort {
    my($self, $params, $listref) = @_;
    my $sub = $params->{sort};
    return if !$sub || !@$listref;
    @$listref = sort { $self->$sub($a,$b) } @$listref;
}

=item current_object([[objid = id | name = name]])

Return the current active object as a C<WE::Obj> object. See also the
C<self> method.

=cut

sub current_object {
    my($self, $params) = @_;
    my $id = $self->current_id($params);
    # XXX check for error?
    my $objdb = $self->{ObjDB};
    my $obj = $objdb->get_object($id);
    if (!$obj) {
	return $self->error("Can't get object with id <$id> from database <" . $objdb->DBFile . ">");
    }
    $obj;
}

=item current_id([[objid = id | name = name]])

Return the current active id. The object is identified in this order:

=over

=item C<objid> in this method call

=item C<name> in this method call

=item C<objid> parameter in the C<Navigation> C<USE> directive

=item C<objid> template variable (as specified in the C<<
Template->new >> call)

=back

=cut

sub current_id {
    my($self, $params) = @_;
    my $id;
    if (defined $params->{objid}) {
	$id = $params->{objid};
    } elsif (defined $params->{name}) {
	$id = $self->{ObjDB}->name_to_objid($params->{name});
    } elsif (defined $self->{ObjID}) {
	$id = $self->{ObjID};
    }
    if (!defined $id) {
	return $self->error("No object id defined. Please define it in either:
* as an objid parameter in the current method call
* as an name parameter (with an existing name) in the current method call
* as an objid parameter in the USE directive
* as an objid template variable
");
    }
    $id;
}

=item self([[objid = id | name = name]])

Return the current active object as a B<...::Navigation::Object> object.

=cut

sub self {
    my($self, $params) = @_;
    my $class = $self->Object;
    $class->new($self->current_object($params), $self);
}

=item get_object([[objid = id | name = name]])

This is an alias for B<self>, but uses a more "logical" name if an
object is retrieved by id or name.

=cut

*get_object = \&self;

=item is_self([$testobj | $testobjid], [[objid = id | name = name]])

Return true if the given C<$testobj> (object) or C<$testobjid> (id) is
the current object. You can pass another C<objid> instead of the
current object. =cut

=cut

sub is_self {
    my($self, $id, $params) = @_;
    $self->idify_params($id);
    my $current_id = $self->current_id($params);
    $id eq $current_id;
}

=item equals([$testobj | $testobjid], [objid = id | name = name])

The same as C<is_self>, only that either C<objid> or C<name> are
mandatory.

Example:

    [% IF n.equals(testobjid, objid = otherobjid) %]

=cut

sub equals {
    my($self, $id, $params) = @_;
    if (!exists $params->{objid} && !exists $params->{name}) {
	die "Either objid or name are mandatory for the equals method";
    }
    $self->is_self($id, $params);
}

=item is_ancestor([$testobj | $testobjid], [objid => id])

Return true if the given C<$testobj> (object) or C<$testobjid> (id) is
an ancestor of the current object. You can pass another C<objid>
instead of the current object. The current object is not considered an
ancestor of itself.

=cut

sub is_ancestor {
    my($self, $objid, $params) = @_;
    $self->idify_params($objid);
    my $current_id = $self->current_id($params);
    return 0 if $objid eq $current_id;
    for my $o ($self->{ObjDB}->pathobjects_with_cache($current_id, undef, $self->{POCache})) {
	return 1 if ($objid eq $o->Id);
    }
    0;
}

=item object_by_name($name)

Return an object by C<$name>.

=cut

sub object_by_name {
    my($self, $name) = @_;
    my $id = $self->{ObjDB}->name_to_objid($name);
    if (defined $id) {
	return $self->self({objid => $id});
    }
    return $self->error("Can't get object by name $name");
}

=item Root

Return reference to root database.

=cut

sub Root { $_[0]->{ObjDB}->Root }

=item ObjDB

Return reference to the object database.

=cut

sub ObjDB { $_[0]->{ObjDB} }

=item Object

Return the class name for the navigation objects. This can be
overridden in inherited classes.

=cut

sub Object {
    "WE_Frontend::Plugin::Navigation::Object";
}

=back

=head2 MEMBERS

Remember that there is no visible distinction in the Template-Toolkit
between accessing members and methods.

=over

=item Context

The C<WEsiteinfo> context.

=item ObjDB

A reference to the object database (C<WE::DB::Obj>).

=back

=head2 INTERNAL METHODS

=over

=item objify_list($listref)

Internal method to create from a list of C<WE::Obj> objects a list of
Navigation objects (see the C<Object> method). The passed parameter
C<$listref> will be changed.

=cut

sub objify_list {
    my($self, $objlistref) = @_;
    my $class = $self->Object;
    @$objlistref = map { $class->new($_, $self) } @$objlistref;
}

=item objectify_params($obj_or_id, $obj_or_id, ...)

Turn the given arguments from an object id or C<WE::Obj> object into
an C<WE_Frontend::Plugin::Navigation::Object> object.

=cut

sub objectify_params {
    my $self = shift;
    my $class = $self->Object;
    my $objdb = $self->{ObjDB};
    for (@_) {
	if (/^\d+$/) { # treat as object id
	    $_ = $objdb->get_object($_);
	} elsif (UNIVERSAL::isa($_, $class)) {
	    # do nothing
	} elsif (UNIVERSAL::isa($_, "WE::Obj")) {
	    $_ = $class->new($_, $self);
	} else {
	    warn "Can't interpret $_ in objectify_params";
	}
    }
}

=item idify_params($obj_or_id, ....)

Turn the given arguments from an object id or C<WE::Obj> object into
an object id.

=cut

sub idify_params {
    my $self = shift;
    my $class = $self->Object;
    my $objdb = $self->{ObjDB};
    for (@_) {
	if (/^\d+$/) { # treat as object id
	    # do nothing
	} elsif (UNIVERSAL::isa($_, $class)) {
	    $_ = $_->o->Id;
	} elsif (UNIVERSAL::isa($_, "WE::Obj")) {
	    $_ = $_->Id;
	} else {
	    warn "Can't interpret $_ in idify_params";
	}
    }
}

# hmmm... the default error() method does not throw an exception
sub error {
    require Carp;
    Carp::confess($_[1]);
}

sub dump {
    my($self, $extra) = @_;
    my $out = "Dump $self:\n";
    require WE::Util::LangString;
    while(my($k,$v) = each %$self) {
	$out .= "$k => " . WE::Util::LangString::langstring($v) . "\n";
    }
    $out .= "\n$extra" if defined $extra;
    $out .= "\n";
    warn $out;
    "";
}

# XXX documentation pending
sub reset_cache {
    my $self = shift;
    $self->{POCache} = {};
}

## Debugging aid:
#  sub DESTROY {
#      my $self = shift;
#      warn $self->{ObjDB}->{CH} if defined $self->{ObjDB} && defined $self->{ObjDB}->{CH};
#  }

1;

__END__

=back

=head2 INTERNALS

Some methods like C<ancestors> or C<is_ancestor> are implemented using
C<WE::DB::Obj::pathobjects_with_cache>. This means that the structure
of the site should not change for a Navigation instance. This is
normally not a problem. XXX see reset_cache

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

