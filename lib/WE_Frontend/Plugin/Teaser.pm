# -*- perl -*-

#
# $Id: Teaser.pm,v 1.3 2004/10/18 15:26:20 eserte Exp $
# Author: Olaf Mätzner
#
# Copyright (C) 2002 Olaf Mätzner
# Copyright (C) 2003 Slaven Rezic
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: oleberlin@users.sourceforge.net
# Mail: eserte@users.sourceforge.net
#

package WE_Frontend::Plugin::Teaser;
use base qw(Template::Plugin);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::Teaser - teaser support

=head1 SYNOPSIS

From Template-Toolkit templates:

    [%- USE t = Teaser(objid=teaserpageid) -%]
    [%- SET teasercontent = t.content(teaser=teasernumber) -%]
    [%- FOREACH item = teasercontent.ct -%]
    ...
    [%- END -%]

=head1 DESCRIPTION

=over

=item Teaser(objid = pageid)

Construct a teaser object with the specified object id.

=item content(teaser = teaser, lang = language)

Return the content of a requested teaser (by teaser number).
Optionally use the specific language. If the C<lang> variable is not
given, then look for the C<lang> variable in the global Template
stash, otherwise fallback to C<de>.

=back

=cut

sub new {
    my($class, $context, $params) = @_;
    $params ||= {};
    my $objdb = $params->{objdb} || $context->stash->get("objdb");
    my $objid = $params->{objid} || $context->stash->get("objid");
    my $lang  = $params->{lang}  || $context->stash->get("lang");
    my $self = {
		Context => $context,
		ObjDB => $objdb,
		ObjID => $objid,
		Lang  => $lang,
	       };
    bless $self, $class;
}

use vars qw($outdata);

sub content {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $objid = defined $params->{objid} ? $params->{objid} : $self->{ObjID};
    my $content = $self->{ObjDB}->content($objid);
    my $teaser = defined $params->{teaser} ? $params->{teaser} : 1;
    my $lang = $params->{lang} || $self->{Lang} || "de";

    $@ = "";
    eval $content;
    if ($@) {
	die "Error while evaluating content <$content>: $@";
    }

#    my(@teasers) = @{ $outdata->{'data'}->{$lang}->{'ct'} };
    # double redirection? XXX
    my(@teasers) = @{ $outdata->{'data'}->{$lang}->{'ct'}->[0]->{'ct'} };
    if (!defined $teasers[$teaser]) {
	require Data::Dumper;
	print STDERR Data::Dumper->new([$outdata, $lang, \@teasers, $teaser],['outdata','lang','teasers','teaser'])->Indent(1)->Useqq(1)->Dump;
	die "There is no teaser with number <$teaser> for language <$lang>, max teaser number is <$#teasers>";
    }
    return $teasers[$teaser];
}

sub old_get_teasercontent {
    my $self = shift;
    my $params = ref($_[$#_]) eq 'HASH' ? pop(@_) : { };
    my $content = $self->{ObjDB}->content($params->{'pageid'});
    my $teaser = 1;#$params->{'teaser'};
    my $lang = "de";#$params->{'lang'};
    ######################
    #
    # $content ist hier ein String mit einem Data:Dump (aus der XX.bin datei)
    #
    #y $ct = '$bla = "hallo"';
    eval $content or return "murks $@";  ## det jeht nich.

    ######################
    # ich will ein Objekt zurückgeben
    # so was hätt ich gerne:

    require Data::Dumper;
    print STDERR Data::Dumper->new([$outdata],[])->Dump;
    my @teasers = $outdata->{'data'}->{$lang}->{'ct'} ;
    return $teasers[$teaser];

}
