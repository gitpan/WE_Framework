# -*- perl -*-

#
# $Id: Main2.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package WE_Frontend::Main2;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

package WE_Frontend::Main;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(Root Config));

use WE_Frontend::MainCommon;

=head1 NAME

WE_Frontend::Main2 - a collection of we_redisys (frontend) related functions

=head1 SYNOPSIS

    use WE_Frontend::Main2;
    my $fe = new WE_Frontend::Main -root => $root, -config => $wesiteinfo_config_object;
    $fe->publish;
    $fe->searchindexer;

=head1 DESCRIPTION

This is the next generation of the old C<WE_Frontend::Main> module.
Both modules share the same methods, but have a different constructor
API.

Note that all methods are loaded into the C<WE_Frontend::Main>.
Therefore it is not possible to use the old and this version of the
module at the same time.

Because of this, you cannot "use base" for inheritance, but rather:

    use WE_Frontend::Main2;
    push @ISA, "WE_Frontend::Main";

=head2 MEMBERS

The C<WE_Frontend::Main2> class has two members: C<Root> and C<Config>.

=head2 METHODS

See the method listing in L<WE_Frontend::MainCommon>.

=cut

sub new {
    my($class, %args) = @_;
    my $self = {};
    bless $self, $class;
    $self->Root($args{-root});
    $self->Config($args{-config});
    $self;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::Main>, L<WE_Frontend::MainCommon>.

=cut

