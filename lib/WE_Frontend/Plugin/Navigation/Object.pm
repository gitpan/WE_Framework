# -*- perl -*-

#
# $Id: Object.pm,v 1.10 2004/10/04 17:05:47 eserte Exp $
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

package WE_Frontend::Plugin::Navigation::Object;

use strict;
use vars qw($VERSION $Navigation);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::Navigation::Object - object for Navigation plugin

=head1 SYNOPSIS

    Not instantiated manually

=head1 DESCRIPTION

The C<WE_Frontend::Plugin::Navigation::Object> objects correspond to
C<WE::Obj> objects.

=head2 METHODS

=over

=cut

sub new {
    my($pkg, $o, $navigation) = @_;
    my $self = {O => $o};
    bless $self, $pkg;
    $self->Navigation($navigation);
    $self;
}

=item Navigation

Return the L<WE_Frontend::Plugin::Navigation> object of the current
object.

Implementation note: This is solved by using a global object because
of self-referencing issues with Perl. This means this will not work if
you have multiple navigation objects in your template (not likely
anyway). However with modern Perl, we could use weaken() instead.

=cut

sub Navigation {
    shift;
    if (@_) {
	$Navigation = $_[0];
    }
    $Navigation;
}

=item o

Return a reference to the L<WE::Obj> object.

=cut

sub o {
    $_[0]->{O};
}

=item get(member)

Return the value of the named member of the L<WE::Obj> object.

=cut

sub get {
    $_[0]->o->{$_[1]}; # XXX evtl. try first method, then member!
}

=item is_doc, is_folder

Return true if the L<WE::Obj> object is a document resp. folder.

=item is_sequence

Return true if the L<WE::Obj> object is a sequence. Remember that a
sequence is always a C<FolderObj>, so a call to C<is_folder> would
also be true.

=cut

foreach my $sub (qw(is_doc is_folder is_sequence
		   )) {
    my $code = 'sub '.$sub.' { $_[0]->o->' . $sub.' }';
    #warn "$code\n";
    eval $code; die $@ if $@;
}

# NYI:
foreach my $sub (qw(lang_title lang_short_title
		    relurl halfabsurl absurl target
		   )) {
    my $code = 'sub '.$sub.' { die "'.$sub.' is NYI" }';
    #warn "$code\n";
    eval $code; die $@ if $@;
}

=item content([lang=lang])

Return the language-specific language content of the current object.
If lang is not specified, then the "de" content is used instead XXX
This will probably change, so don't rely on it! See also L</data>.

This corresponds to things=data.${data.language}.ct as seen in the
sample webeditor templates.

=cut

sub content {
    my($self, $params) = @_;
    if (!$params || !$params->{lang}) {
	$params->{lang} = "de"; # XXX how to get default language???
    }
    $self->data->{$params->{lang}}->{ct};
}

=item data

Return the data content of the current object. See also L</content>.

=cut

sub data {
    my($self) = @_;
    my $content;
    require WE_Content::Base;
    my $content_file = $self->Navigation->{RootDB}->ContentDB->filename($self->o->Id);
    my $perldd = WE_Content::Base->new(-file => $content_file);
    $content = $perldd->{Object}->{'data'};
    $content;
}

sub dump {
    my($self, $extra) = @_;
    my $out = "Dump $self:\n";
    require WE::Util::LangString;
    while(my($k,$v) = each %{ $self->o }) {
	$out .= "$k => " . WE::Util::LangString::langstring($v) . "\n";
    }
    $out .= "\n$extra" if defined $extra;
    $out .= "\n";
    warn $out;
    "";
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Obj>.

=cut

