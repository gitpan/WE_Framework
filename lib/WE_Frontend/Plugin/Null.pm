# -*- perl -*-

#
# $Id: Null.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package WE_Frontend::Plugin::Null;
use base qw(Template::Plugin);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::Null - null plugin which can print an important sentence

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE Null %]
    [% Null.helloworld %]

=head1 DESCRIPTION

This is only a demonstration module for the plugin mechanism.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context) = @_;
    my $self = {Context => $context};
    bless $self, $class;
}

=item helloworld

Return the important sentence.

=cut

sub helloworld {
    return "Hello, world!";
}

=item selfeval("templatevar")

Return the value of the named template variable.

=cut

sub selfeval {
    my($self, $arg) = @_;
    return $self->{Context}->stash->get($arg);
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>.

=cut

