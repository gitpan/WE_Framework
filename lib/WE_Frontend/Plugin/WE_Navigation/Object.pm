# -*- perl -*-

#
# $Id: Object.pm,v 1.15 2004/11/03 21:56:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::WE_Navigation::Object;

use base qw(WE_Frontend::Plugin::Navigation::Object);

use strict;
use vars qw($VERSION $IGNORE_NAME_DB $DONT_USE_INDEXDOC);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::WE_Navigation::Object - object for WE_Navigation plugin

=head1 SYNOPSIS

    Normally not instantiated.

=head1 DESCRIPTION

This is a specialization of
L<WE_Frontend::Plugin::Navigation::Object>. This class has additional
methods for retrieving language titles, relative and absolute urls.

=head2 METHODS

=over 4

=item ext

Return default extension (by default ".html"). May be overwritten in a
subclass.

=cut

sub ext { ".html" }

sub _set_lang {
    my $self = shift;
    if (!defined $_[0]) {
	$_[0] = $self->Navigation->{Context}->stash->get("lang") || "en";
    }
}

=item lang_title([lang])

The language dependent title. C<lang> is optional. English will be
used if other means to determine the language fail.

=cut

sub lang_title {
    my($self, $lang) = @_;
    $self->_set_lang($lang);
    require WE::Util::LangString;
    WE::Util::LangString::get($self->_obj_version_proxy("title")->o->{Title}, $lang);
}

=item lang_short_title([lang])

Short title. (NYI)

=cut

sub lang_short_title {
    shift->lang_title(@_);
}

=item relurl

Return a relative URL to the object.

Use the name from NameDB if available. See also the C<$IGNORE_NAME_DB>
variable to turn this feature of.

If the object is an folder, then the C<IndexDoc> doc is used instead
for the URL. If C<IndexDoc> is undefined, then the C<autoindexdoc>
feature handling fires. This feature may be turned off by
C<$DONT_USE_INDEXDOC>.

=cut

sub relurl {
    my $self = shift;
    my $n = $self->Navigation;
    my $config = $n->{Config};
    my $objdb  = $n->{ObjDB};
    my $o = $self->_obj_version_proxy("url")->o;

    # Resolve id for folders
    my $id = defined $o->Version_Parent ? $o->Version_Parent : $o->Id;
    if (!$DONT_USE_INDEXDOC && $o->can("IndexDoc")) {
	if (defined $o->IndexDoc && $o->IndexDoc ne "") {
	    $id = $o->IndexDoc;
	} elsif ($config &&
		 $config->project &&
		 $config->project->can("features") &&
		 $config->project->features &&
		 $config->project->features->{autoindexdoc} &&
		 $config->project->features->{autoindexdoc} eq 'first') {
	    # XXX code doubled in WebEditor::OldController!
	    my(@children_ids) = $objdb->get_released_children($id);
	    if (@children_ids) {
		$id = $children_ids[0]->Id;
	    }
	}
    }

    # Prefer name over numerical id
    my $rootdb = $n->{RootDB};
    if ($rootdb && !$IGNORE_NAME_DB) {
	my $namedb = $rootdb->NameDB;
	if ($namedb) {
	    my @names = $namedb->get_names($id);
	    if (@names) {
		return $names[0] . $self->ext;
	    }
	}
    }

    if ($objdb->is_root_object($id)) {
	"index" . $self->ext;
    } else {
	$id . $self->ext;
    }
}

=item halfabsurl

Return a half-absolute URL (without scheme, host and port part) to the
object.

=cut


sub halfabsurl {
    my($self, $lang) = @_;
    $self->_set_lang($lang);
    my $config = $self->Navigation->{Config};
    $config->paths->rooturl . "/html/$lang/" . $self->relurl;
}

=item absurl

Return an absolute URL (with scheme, host and port part) to the
object.

=cut

sub absurl {
    my($self, $lang) = @_;
    $self->_set_lang($lang);
    my $config = $self->Navigation->{Config};
    $config->paths->absoluteurl . "/html/$lang/" . $self->relurl;
}

=item target

Return the window target to the object. Currently this is always
"_self".

=cut

sub target {
    "_self";
}

=item include_in_navigation

Return true if the object should be included to the navigation. The
following cases cause the object to be excluded from the navigation:

=over

=item * The object's attribute C<Release_State> is not C<released>

=item * The object's attribute C<Navigation> is C<hidden>

=item * The object is not ready to be published as determined by
C<TimeOpen> and C<TimeExpire>. The current date can be adjusted by
setting the C<localconfig.now> template variable to a unix epoch time.

=back

=cut

sub include_in_navigation {
    my($self) = @_;
    my $o = $self->_obj_version_proxy("navigation")->o;
    return 0 if ((defined $o->{Navigation}  && $o->{Navigation} eq 'hidden') ||
		 (!defined $o->Release_State || $o->Release_State ne 'released'));
    if (defined $o->TimeOpen || defined $o->TimeExpire) {
	my $n = $self->Navigation;
	my $now = $n->{LocalConfig}{now};
	$now = time if !defined $now;
	return 0 if $o->is_time_restricted($now);
    }
    1;
}

=item obj_proxy($caller)

Some objects may not have content of their own and use the first child
in their collection instead for getting attributes like Title etc. By
default, this method just returns the object itself, but may be
overriden. See C<WE_Frontend::Plugin::WE_Navigation> for an example.

C<$caller> will be set to a symbolic name of the caller: C<title> (for
methods like C<lang_title>), C<url> (for methods like C<relurl>), or
C<navigation>) (for C<include_in_navigation> and similar methods). If
you need the real caller function name, then use the standard C<caller>
function.

=cut

sub obj_proxy { $_[0] }

=item version_proxy($caller)

For a given object, determine which version of the object should be
used. The default implementation of I<version_proxy> is to return the
last released version (using I<get_released_object> from
L<WE::DB::Obj>), or, if no object is released, the latest version.
Subclasses are free to override this method.

=cut

sub version_proxy {
    my($self, $caller) = @_;
    my $n = $self->Navigation;
    my $objdb  = $n->{ObjDB};
    my $relobj = $objdb->get_released_object($self->o->Id);
    if (!defined $relobj) {
	return $self;
    }
    my $ret = (ref $self)->new($relobj, $n);
    $ret;
}

# Call obj_proxy and version_proxy. Only for internal use.
sub _obj_version_proxy {
    my($self, $caller) = @_;
    $self->obj_proxy($caller)->version_proxy($caller);
}

__END__

=back

=head2 GLOBAL VARIABLES

=over

=item $IGNORE_NAME_DB

If set to a true value, then do not use the name database in relurl.

=item $DONT_USE_INDEXDOC

If set to a true value, then neither use the C<IndexDoc> nor the
C<autoindexdoc> features.

=back

=head1 EXAMPLES

Here are some examples for using this plugin in templates:

    [% USE n = WE_Navigation -%]
    [% FOR p = n.siblings -%]
      [% IF p.include_in_navigation -%]
      <a href="[% p.relurl | html %]">[% p.lang_title | html %]</a><br />
      [% END -%]
    [% END -%]

=head1 HISTORY

From version 1.11 the relurl and related methods handle the IndexDoc
value of folders and in absence of this value look at the autoindexdoc
feature.

From version 1.09 the relurl and related methods prefer to construct a
symbolic URL with the help of the NameDB. Older versions always
constructed an URL using the numerical id.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::Plugin::Navigation::Object>.

=cut

