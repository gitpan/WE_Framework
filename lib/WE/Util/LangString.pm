# -*- perl -*-

#
# $Id: LangString.pm,v 1.8 2004/04/05 20:33:05 eserte Exp $
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

package WE::Util::LangString;

use base 'Exporter';

use strict;
use vars qw($VERSION @EXPORT_OK $DEFAULT_LANG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(new_langstring langstring set_langstring);

$DEFAULT_LANG = 'en' unless defined $DEFAULT_LANG;

=head1 NAME

WE::Util::LangString - language-dependent strings

=head1 SYNOPSIS

    use WE::Util::LangString qw(new_langstring langstring set_langstring);

=head1 DESCRIPTION

This module deals with language-dependent strings.

=head1 METHODS

=over 4

=item WE::Util::LangString->new(en => "english title", de => "german title")

Create a new C<WE::Util::LangString> object and optionally initializes
the object with values.

=cut

sub new {
    my($class, %args) = @_;
    my $self = {%args};
    bless $self, $class;
}

=item new_langstring(en => "english title", de => "german title")

Same as the C<new> constructor, but shorter form.

=cut

sub new_langstring { WE::Util::LangString->new(@_) }

=item $obj->get([$language])

Get the value for the specified language. If no language is specified
or there is no language value in the object, then the english version
is returned. If there is no english version, return the first value
found in the object.

=item $obj->langstring([$language])

=item langstring($string, [$language])

This is an alias for C<get>.

=cut

sub get {
    my($self, $language) = @_;
    if (UNIVERSAL::isa($self, __PACKAGE__)) {
	defined $language && exists $self->{$language}
	    ? $self->{$language} # use language string asked for...
		: exists $self->{'en'}
		    ? $self->{'en'} # use english fallback
			: $self->{(keys %$self)[0]}; # use first one
    } else {
	# treat $self as a string
	$self;
    }
}

*langstring = \&get;

=item set_langstring($obj,$language,$string,[$default_language])

Set the string C<$string> for language C<$language> to the object
C<$obj>. If C<$obj> is not yet a C<WE::Util::LangString> object, then
it will be blessed automatically into it. If C<$language> is not
specified, then a default language (as set in C<$DEFAULT_LANG>,
normally english) is used.

=cut

sub set_langstring {
    my($lang, $string, $default_lang) = @_[1..3];
    if (!UNIVERSAL::isa($_[0], __PACKAGE__)) {
	$default_lang = $DEFAULT_LANG unless defined $default_lang;
	$_[0] = __PACKAGE__->new($default_lang => $_[0]);
    }
    $_[0]->{$lang} = $string;
    $_[0];
}

=item dump

Dump the content of the langstring as a one-line string.

=cut

sub dump {
    my $self = shift;
    my @s;
    foreach my $lang (sort keys %$self) {
	my $val = $self->{$lang};
	$val = "(undef)" if !defined $val;
	push @s, "$lang: $val";
    }
    join(", ", @s);
}

=item concat($oldstr, $newstr)

Add C<$newstr> to C<$oldstr>. If C<$oldstr> is a
C<WE::Util::LangString> object, than add C<$newstr> to all language
variants in the object. If both arguments are C<WE::Util::LangString>
objects, then the corresponding language versions are concatenated.

=cut

sub concat ($$) {
    if (UNIVERSAL::isa($_[0], __PACKAGE__)) {
	if (UNIVERSAL::isa($_[1], __PACKAGE__)) {
	    while(my($k,$v) = each %{ $_[1] }) {
		if (exists $_[0]->{$k}) {
		    $_[0]->{$k} .= $v;
		}
	    }
	} else {
	    while(my($k) = each %{ $_[0] }) {
		$_[0]->{$k} .= $_[1];
	    }
	}
    } else {
	$_[0] .= $_[1];
    }
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

