# -*- perl -*-

#
# $Id: Main.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Main;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use WEsiteinfo (); # do not export anything

use WE_Frontend::MainCommon;
use WE_Frontend::Info;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(Root Config));

=head1 NAME

WE_Frontend::Main - a collection of we_redisys (frontend) related functions

=head1 SYNOPSIS

    use WE_Frontend::Main;
    my $fe = new WE_Frontend::Main $root;
    $fe->publish;
    $fe->searchindexer;

=head1 DESCRIPTION

This module is obsolete and only for backward compatibility. Please
use L<WE_Frontend::Main2> instead.

=head2 METHODS

See the method list in L<WE_Frontend::MainCommon>.

=head2 CONFIGURATION VARIABLES

Please consult the source (function C<_pseudo_wesiteinfo_obj>) to see
which configuration variables match the new-style members. For
example, the new

    $c->paths->rootdir

corresponds to the old

    $WEsiteinfo::rootdir

=cut

sub new {
    my($class, $root) = @_;
    my $self = {};
    bless $self, $class;
    $self->Root($root);
    $self->Config(_pseudo_wesiteinfo_obj());
    $self;
}

sub _pseudo_wesiteinfo_obj {
    my $c = bless {}, 'WEsiteinfo';
    my $paths = bless {}, 'WEsiteinfo::Paths';
    $paths->rootdir($WEsiteinfo::rootdir);
    $paths->cgidir($WEsiteinfo::cgidirfs);
    $paths->pubhtmldir($WEsiteinfo::pubhtmldir);
    $c->paths($paths);
    my $staging = bless {}, 'WEsiteinfo::Staging';
    $staging->transport($WEsiteinfo::livetransport);
    $staging->user($WEsiteinfo::liveuser);
    $staging->password($WEsiteinfo::livepassword);
    $staging->host($WEsiteinfo::livehost);
    $staging->directory($WEsiteinfo::livedirectory);
    $staging->cgidirectory($WEsiteinfo::livecgidirectory);
    $staging->stagingext($WEsiteinfo::livestagingext);
    $c->staging($staging);
    my $search = bless {}, 'WEsiteinfo::SearchEngine';
    $search->searchindexer($WEsiteinfo::searchindexer);
    $c->searchengine($search);
    my $p = bless {}, 'WEprojectinfo';
    $p->stagingextracgi([@WEsiteinfo::stagingextracgi]);
    $c->project($p);
    $c;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::MainCommon>.

=cut

