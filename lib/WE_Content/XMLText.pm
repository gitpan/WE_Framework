# -*- perl -*-

#
# $Id: XMLText.pm,v 1.5 2004/12/21 23:19:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Content::XMLText;
use base qw(WE_Content::Base);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use Carp;
use XML::Parser ();
use Storable qw(dclone);

{
    # Simple minded writer which is sufficient for this module,
    # but better than XML::Writer!
    package My::XML::Writer;
    sub new {
	my $class = shift;
	my $self = bless { T => "" }, $class;
    }
    sub as_string {
	shift->{T};
    }
    sub startTag {
	my($self, $tag, @attr) = @_;
	my $t = \$self->{T};
	$$t .= "<$tag";
	for(my $i=0; $i<$#attr; $i+=2) {
	    $$t .= " $attr[$i]='$attr[$i+1]'";
	}
	$$t .= ">";
	push @{ $self->{LastOpen} }, $tag;
    }
    sub endTag {
	my($self, $tag) = @_;
	my $last_open = pop @{ $self->{LastOpen} };
	if (defined $tag) {
	    if ($tag ne $last_open) {
		die "Mismatch tag: $tag != $last_open";
	    }
	} else {
	    $tag = $last_open;
	}
	$self->{T} .= "</$tag>\n";
    }
    sub characters {
	my($self, $data) = @_;
	if ($data =~ /[\&\<\>]/) {
	    $data =~ s/\&/\&amp\;/g;
	    $data =~ s/\</\&lt\;/g;
	    $data =~ s/\>/\&gt\;/g;
	}
	# Unicodify
	if ($] >= 5.008) {
	    require Encode;
	    # Make sure the data is characters, but with utf8 flag turned on
	    if (!Encode::is_utf8($data)) {
		$data = Encode::decode("iso-8859-1", $data);
	    }
	} elsif ($] >= 5.006) {
	    $data .= "\x{0100}";
	    $data = substr($data, 0, -1);
	} else {
	    warn "XXX not yet tested";
	    require Unicode::String;
	    my $us = Unicode::String->new;
	    $us->latin1($data);
	    $data = $us->utf8;
	}
	$self->{T} .= $data;
    }
}

sub new {
    my($class, %args) = @_;
    my $self = {};
    while(my($k,$v) = each %args) {
	croak "Option does not start with a dash: $k" if $k !~ /^-/;
	$self->{ucfirst(substr($k,1))} = $v;
    }
    bless $self, $class;
    if ($self->{File}) {
	$self->parse(-file => $self->{File});
    } elsif ($self->{String}) {
	$self->parse(-string => $self->{String});
    }
    $self;
}

sub _create_parser {
    my $self = shift;
    my $p = $self->{P} = XML::Parser->new;
    $p->setHandlers(Start => sub { $self->_start_handler(@_) },
		    End   => sub { $self->_end_handler(@_)   },
		    Char  => sub { $self->_char_handler(@_)  },
		   );
    $p;
}

sub _start_handler {
    my($self, undef, $elem, %attr) = @_;
    $self->{CurrentTag} = $elem;
    if ($elem eq 'webeditordoc') {
	my $lang = $self->{CurrentLang} = $attr{"lang"};
	my $oldlang = $attr{"oldlang"};
	$oldlang = $self->{Oldlang} if !defined $oldlang;
	if (!$oldlang) {
	    die "Missing -oldlang parameter";
	}
	if (!$self->{Templateobject}{data}{$oldlang}) {
	    die "Missing language $oldlang in template object, found only: " . join(", ", keys %{ $self->{Templateobject}{data} });
	}
	$self->{Templateobject}{data}{$lang} =
	    dclone $self->{Templateobject}{data}{$oldlang};
    } else {
	$self->{CurrentPath} = $attr{"path"};
    }
    $self->{CurrentCharacters} = "";
}

sub _end_handler {
    my($self, undef, $elem) = @_;
    if ($elem eq 'val') {
	my $path = $self->{CurrentPath} || die "path missing";
	my(@path) = split /\./, $path;
	if (shift(@path) ne "root") {
	    die "path should start with 'root'";
	}
	my $ref = $self->{Templateobject}{data};
	my $lang = $self->{CurrentLang} || die "lang missing";
	$ref = $ref->{$lang};
	for my $i (0 .. $#path-1) {
	    my $elem = $path[$i];
	    if (ref $ref eq 'ARRAY') {
		$ref = $ref->[$elem];
	    } elsif (ref $ref eq 'HASH') {
		$ref = $ref->{$elem};
	    } else {
		undef $ref;
	    }
	    if (!$ref) {
		local $^W = 0;
		die "Could not resolve path `$path', failed at `$elem'. Element is `$ref'";
	    }
	}
	my $s = $self->{CurrentCharacters};
	if ($self->debug) {
	    warn "Set `$path' to `$s'\n";
	}
	if (ref $ref eq 'ARRAY') {
	    $ref->[$path[-1]] = $s;
	} else {
	    $ref->{$path[-1]} = $s;
	}
    }
}

sub _char_handler {
    my($self, undef, $string) = @_;
    $self->{CurrentCharacters} .= $string;
}

sub parse {
    my($self, %args) = @_;

    if (!$self->{Templateobject}) {
	croak "Missing -templateobject parameter";
    }

    my $buf = $self->get_string(%args);
    if (!$self->{P}) { $self->_create_parser }
    eval {
	$self->{P}->parse($buf);
    };
    if ($@) {
	my $line = 1;
	warn join("\n", map { sprintf("%3d: %s", $line++, $_) } split /\n/, $buf);
	croak $@;
    }

    $self->{Object} = $self->{Templateobject};

    $self->{Object};
}

sub serialize {
    my($self, %args) = @_;
    my $lang = $args{-lang} || croak "-lang parameter is missing";
    my $oldlang = $args{-oldlang};
    my $xmlw = My::XML::Writer->new;
    $xmlw->startTag("webeditordoc", "lang", $lang,
		    (defined $oldlang ? ("oldlang", $oldlang) : ()),
		   );
    $self->_serialize($self->{Object}{'data'}{$lang}, "root", $xmlw);
    $xmlw->endTag("webeditordoc");
    my $data = "<?xml version='1.0' encoding='utf-8'?>\n" .
	"<!DOCTYPE webeditordoc SYSTEM 'webeditordoc.dtd'>\n" .
	    $xmlw->as_string;
    if ($] >= 5.008) {
	# Write out utf-8 as octets.
	$data = Encode::encode("utf-8", $data);
    } else {
	warn "XXX not yet tested";
    }
    $data;
}

sub _serialize {
    my($self, $ref, $path, $xmlw) = @_;
    if (ref $ref eq 'HASH') {
	while(my($k,$v) = each %$ref) {
	    if ($k =~ /^(text|title)$/) { # XXX add here more translatable keys (or make configurable)
		$xmlw->startTag("val",
			       "path" => "$path.$k");
		$xmlw->characters($v);
		$xmlw->endTag;
	    } elsif (ref $v) {
		$self->_serialize($v, "$path.$k", $xmlw);
	    }
	}
    } elsif (ref $ref eq 'ARRAY') {
	for my $i (0 .. $#$ref) {
	    my $v = $ref->[$i];
	    if (ref $v) {
		$self->_serialize($v, "$path.$i", $xmlw);
	    }
	}
    }
}

sub ext { "xml" }

1;

__END__

=head1 NAME

WE_Content::XMLText - minimal web.editor text content in XML files

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a serializer/deserializer of web.editor text content only. The
XML output is useful for translation processes.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Base>, L<WE_Content::XML>, L<XML::Parser>

=cut

