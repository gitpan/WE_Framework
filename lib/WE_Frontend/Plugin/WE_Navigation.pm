# -*- perl -*-

#
# $Id: WE_Navigation.pm,v 1.10 2004/06/17 08:58:44 eserte Exp $
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

package WE_Frontend::Plugin::WE_Navigation;
use base qw(WE_Frontend::Plugin::Navigation);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

require WE_Frontend::Plugin::WE_Navigation::Object;

sub new {
    my($class, $context, $params) = @_;
    $params ||= {};
    my $self = $class->SUPER::new($context, $params);
    $self->{Config} = $params->{config} || eval { $context->stash->get("config") } || {};
    $self->{LocalConfig} = $params->{localconfig} || eval { $context->stash->get("localconfig") } || {};
    bless $self, $class;
}

sub Object {
    "WE_Frontend::Plugin::WE_Navigation::Object";
}

1;

__END__

=head1 NAME

WE_Frontend::Plugin::WE_Navigation - specialized navigation plugin

=head1 SYNOPSIS

    [% USE n = WE_Navigation %]
    [% USE n = WE_Navigation(objid = 12) %]

=head1 DESCRIPTION

L<WE_Frontend::Plugin::WE_Navigation> is a subclass of
L<WE_Frontend::Plugin::Navigation>. Instead of
L<WE_Frontend::Plugin::Navigation::Object> as underlying objects, it
uses L<WE_Frontend::Plugin::WE_Navigation::Object> objects.

The following global Template variables are used additionally:

=over 4

=item lang

Current language, if the C<lang> parameter is not defined in the
L<WE_Frontend::Plugin::Navigation::Object> methods C<lang_title>,
C<lang_short_title>, C<halfabsurl> and C<absurl>. If C<lang> is not
set, then usually "en" will be used instead.

=item config

The L<WE_Frontend::Info> object, also known as C<WEsiteinfo> object.
This is used to get absolute URLs for the C<halfabsurl> and C<absurl>
methods.

=item localconfig

To pass other parameters, use the C<localconfig> variable. For now,
the C<localconfig.now> is used for determining the current time for
time based publish processes.

=back

=head1 USE YOUR OWN SUBCLASSES

Here is an example for an own subclass derived from
C<WE_Frontend::Plugin::WE_Navigation>:

    package WE_Sample::Plugin::MyNavigation;
    use base qw(WE_Frontend::Plugin::WE_Navigation);

    sub Object {
        "WE_Frontend::Plugin::MyNavigation::Object";
    }

    package WE_Sample::Plugin::MyNavigation::Object;
    use base qw(WE_Frontend::Plugin::WE_Navigation::Object);

    sub obj_proxy {
        my $self = shift;
        # put your definition here
        if ($self->o->is_folder) {
            # return first child of folder
            ...
        } else {
            $self;
        }
    }

    sub relurl {
        # put your definition here
        ...
    }

    1;

This could be put into a file called
C<WE_Sample/Plugin/MyNavigation.pm>. Now you can override methods in
the C<WE_Sample::Plugin::MyNavigation::Object> class.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::Plugin::Navigation>,
L<WE_Frontend::Plugin::WE_Navigation::Object>.

=cut

