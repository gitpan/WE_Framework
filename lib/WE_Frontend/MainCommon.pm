# -*- perl -*-

#
# $Id: MainCommon.pm,v 1.8 2004/10/26 11:38:44 eserte Exp $
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

package WE_Frontend::MainCommon;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

package WE_Frontend::Main;

=head1 NAME

WE_Frontend::MainCommon - common methods for all WE_Frontend::Main* modules

=head1 SYNOPSIS

    Do not use this module at its own!!! Just consult the methods.

=head1 DESCRIPTION

Note that all methods are loaded into the C<WE_Frontend::Main> namespace.

=head2 METHODS

=over 4

=item publish

Use the appropriate publish method according to the
WEsiteinfo::Staging config member C<livetransport>. May return a hash
reference with following members:

=over 4

=item Directories

List reference of published directories.

=item Files

List reference of published files.

=back

Options to publish:

=over 4

=item -verbose

Be verbose if set to true.

=item -adddirectories

Reference to an array with additional directories to be published.

=item -addfiles

Reference to an array with additional files to be published.

=back

C<livetransport> may be any of the standard ones: C<rsync>, C<ftp>,
C<ftp-md5sync>, C<rdist>, or C<rdist-ssh>. For custom methods, use
either of the following:

=over

=item C<custom:I<method_name>>

Where I<method_name> has to be a method in the C<WE_Frontend::Main>
namespace and already loaded in

=item A base class name I<basename>

This will cause to load a module with the name
C<WE_Frontend::Publish::I<basename>> (with uppercase basename) and
call a method C<publish_I<basename>> (lowercase).

=item A fully qualified method

This will case to require the module (based on the package name of the
method) and call this method.

=back

=cut

sub publish {
    my $self = shift;

    my $livetransport = $self->Config->staging->transport;

    if (!defined $livetransport || $livetransport eq '') {
	die "Transport protocol WEsiteinfo->staging->transport for publish not defined";
    }
    if ($livetransport eq 'rsync') {
	require WE_Frontend::Publish::Rsync;
	$self->publish_rsync(@_);
    } elsif ($livetransport eq 'ftp') {
	require WE_Frontend::Publish::FTP;
	$self->publish_ftp(@_);
    } elsif ($livetransport eq 'ftp-md5sync') {
	require WE_Frontend::Publish::FTP_MD5Sync;
	$self->publish_ftp_md5sync(@_);
    } elsif ($livetransport eq 'rdist') {
	require WE_Frontend::Publish::Rdist;
	$self->publish_rdist(@_);
    } elsif ($livetransport eq 'rdist-ssh') {
	require WE_Frontend::Publish::Rdist;
	$self->publish_rdist(@_, -transport => 'ssh');
    } elsif ($livetransport eq 'tgz') {
	require WE_Frontend::Publish::Tgz;
	$self->publish_tgz(@_);
    } elsif ($livetransport =~ /^custom:(.*)/) {
	my $method = $1;
	$self->$method(@_);
    } else {
	my $meth;
	my $cmd = "require WE_Frontend::Publish::" . ucfirst($livetransport) . "; 1";
	#warn "eval $cmd";
	eval $cmd;
	if ($@) {
	    my($mod, $method) = $livetransport =~ /^(.*)::(.*)$/;
	    if (defined $mod && defined $method) {
		my $cmd = "require $mod; 1";
		#warn "eval $cmd";
		eval $cmd;
		if ($@) {
		    die "Transport protocol WEsiteinfo->staging->transport `$livetransport' can't be handled: $@";
		}
		$meth = $method;
	    }
	}
	if (!$meth) {
	    $meth = $self->can('publish_' . $livetransport);
	}
	if (!$meth) {
	    die "Publish method for `$livetransport' not defined";
	}
	$self->$meth(@_);
    }
}

=item searchindexer

XXX This method is not used XXX.

Use the appropriate search indexer method according to the
WEsiteinfo::SearchEngine config member C<searchindexer>.

C<searchindexer> may take any of the following standard values:
C<htdig> or C<oosearch>.

=cut

sub searchindexer {
    my $self = shift;

    my $searchindexer = $self->Config->searchengine->searchindexer;

    if (!defined $searchindexer || $searchindexer eq '') {
	die "Search indexer WEsiteinfo->searchengine->searchindexer not defined";
    }
    if ($searchindexer eq 'htdig') {
	require WE_Frontend::SearchIndexer::Htdig;
	$self->searchindexer_htdig(@_);
    } elsif ($searchindexer eq 'oosearch') {
	require WE_Frontend::SearchIndexer::OOSearch;
	$self->searchindexer_oosearch(@_);
    } else {
	my $meth;
	my $cmd = "require WE_Frontend::SearchIndexer::" . ucfirst($searchindexer) . "; 1";
	#warn "eval $cmd";
	eval $cmd;
	if ($@) {
	    my($mod, $method) = $searchindexer =~ /^(.*)::(.*)$/;
	    my $cmd = "require $mod; 1";
	    #warn "eval $cmd";
	    eval $cmd;
	    if ($@) {
		die "Transport protocol WEsiteinfo->searchengine->searchindexer is unknown: $@";
	    }
	    $meth = $method;
	} else {
	    $meth = $self->can('searchindexer_' . $searchindexer);
	}
	if (!$meth) {
	    die "Search indexer for $searchindexer not defined";
	}
	$self->$meth(@_);
    }
}

=item linkchecker

Checks recursively all links from C<-url> (which may be a scalar or an
array reference), or for all languages homepages. By default, the
language homepages should be in

     $c->paths->rooturl . "/html/" . $lang . "/" . "home.html"

but the last part ("home.html") can be changed by the C<-indexhtml>
argument.

=cut

sub linkchecker {
    my $self = shift;
    my(%args) = @_;

    require WE_Frontend::LinkChecker;
    my $url = delete $args{-url};
    if (!$url) {
	my $indexhtml = delete $args{-indexhtml} || "home.html";
	foreach my $lang (@{ $self->Config->project->sitelanguages }) {
	    push @$url, $self->Config->paths->rooturl . "/html/" . $lang . "/$indexhtml";
	}
    }

    my $lc = WE_Frontend::LinkChecker->new(-url => $url, %args);
    $lc->check_html;
}

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::Main>, L<WE_Frontend::Main2>.

=cut

1;
