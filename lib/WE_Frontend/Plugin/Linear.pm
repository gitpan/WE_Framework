# -*- perl -*-

#
# $Id: Linear.pm,v 1.6 2004/01/28 16:45:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::Linear;
use base qw(Template::Plugin);

use HTML::Entities;

use WE_Frontend::Plugin::WE_Navigation;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::Linear - assume hierarchy as a "linear" list

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE Linear %]
    [% SET o = Linear.prev() %]
    [% SET o = Linear.next() %]

=head1 DESCRIPTION

This plugin assumes web.editor objects like linear pages as in books.
The returned objects are L<WE_Frontend::Plugin::WE_Navigation::Object>
objects.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context, $params) = @_;
    my $n = WE_Frontend::Plugin::WE_Navigation->new($context, $params);
    my $self = { WE_Navigation => $n };
    bless $self, $class;
}

sub restrict_code {
    return sub {
        my $o = shift;
	return $o->o->{VisibleToMenu};
    };
}

sub _prev_next {
    my($self, $dir, $nav_obj) = @_;
    my $wen = $self->{WE_Navigation};
    my $restrict = $self->restrict_code;
    my $objid = $nav_obj->o->Id;
    my %std_args = (objid    => $objid,
		    restrict => $restrict);
    my $siblings = $wen->siblings(\%std_args);
    for my $i (0 .. $#$siblings) {
	my $o = $siblings->[$i];
	if ($o->o->Id eq $objid) {
	    if (($dir > 0 && $i == $#$siblings) ||
		($dir < 0 && $i == 0)) {
		my $level = $wen->level(\%std_args);
		if ($level == 0) {
		    return undef; # we're already at the top (home of the site)
		}
		my $upper_siblings = $wen->siblings({ %std_args,
						      level => $level - 1});
		my $parent = $wen->parent(\%std_args);
		if ($dir > 0) {
		    return $self->_next($parent);
		} else {
		    my $p = $self->_prev($parent);
		    return $self->last($p);
		}
	    }
	    if ($dir < 0 && $siblings->[$i + $dir]) {
		return $self->last($siblings->[$i + $dir]);
	    } else {
		return $siblings->[$i + $dir];
	    }
	}
    }
    warn "Object id $objid: Can't find myself --- this may happen if the page is not included in the navigation" if $DEBUG;
    undef;
}

=item prev()

Get the previous object (or undef).

=cut

sub _prev { shift->_prev_next(-1, @_) }

sub prev {
    my($self) = @_;
    my $wen = $self->{WE_Navigation};
    $self->_prev($wen->self);
}

=item next()

Get the next object (or undef).

=cut

sub _next { shift->_prev_next(+1, @_) }

sub next {
    my($self) = @_;
    my $wen = $self->{WE_Navigation};
    $self->_next($wen->self);
}

=item last()

Get the last object, probably by recursing into subdirectories.

=cut

sub last {
    my($self, $nav_obj) = @_;
    my $wen = $self->{WE_Navigation};
    my $restrict = $self->restrict_code;
    my %std_args = (objid    => $nav_obj->o->Id,
		    restrict => $restrict);
    my $children = $wen->children(\%std_args);
    if (!@$children) {
	# no children - return object itself
	return $nav_obj;
    }
    $self->last($children->[-1]);
}


1;

__END__

=back

=head1 EXAMPLES

Here's a usage example for the Linear plugin, creating back and
forward links:

  [% USE Linear -%]
  [% SET prev = Linear.prev -%]
  [% SET next = Linear.next -%]
  <noindex><!--htdig_noindex-->
  [% IF prev -%]<a class="breadcrumb" href="[% prev.relurl %]">&lt;&lt;</a>&nbsp;&nbsp;[% END -%]
  [% IF next -%]<a class="breadcrumb" href="[% next.relurl %]">&gt;&gt;</a>&nbsp;[% END -%]
  <!--/htdig_noindex--></noindex>

Or for just creating a (multilingual) "next page" link:

  [% USE Linear -%]
  [% SET next = Linear.next -%]
  [% IF next -%]<a class="navi" href="[% next.relurl %]"><img src="[% rooturl %]/images/arrow.gif" border="0"><noindex><!--htdig_noindex--> [% IF lang == "de" %]N&auml;chste Seite[% ELSE %]Next page[% END %]: [% next.lang_title | html %]<!--/htdig_noindex--></noindex></a>[% END -%]

Note the presence of the noindex tags --- these help htdig to ignore
the contentfor the excerpts.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>, L<WE_Frontend::Plugin::WE_Navigation>, L<htdig(1)>.

=cut

