# -*- perl -*-

#
# $Id: XML.pm,v 1.7 2004/03/21 23:11:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Content::XML;
use base qw(WE_Content::Base);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use XML::Dumper 0.71 (); # earlier versions were not reliable

sub new {
    my($class, %args) = @_;
    my $self = {};
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	$self->{ucfirst(substr($k,1))} = $v;
    }
    bless $self, $class;
    if ($self->{File}) {
	$self->parse(-file => $self->{File});
    } elsif ($self->{String}) {
	$self->parse(-string => $self->{String});
    }
    $self->_create_parser;
    $self;
}

sub _create_parser {
    my $self = shift;
    $self->{P} = XML::Dumper->new;
}

sub parse {
    my($self, %args) = @_;
    my $buf = $self->get_string(%args);

    my $emptydata;
    if (!$self->{P}) { $self->_create_parser }
    my $outdata = eval { local $SIG{__DIE__}; $self->{P}->xml2pl($buf) };
    if ($@) {
	my $line = 1;
	warn join("\n", map { sprintf("%3d: %s", $line++, $_) } split /\n/, $buf);
	die $@;
    }
    if (!defined $outdata) {
	die "Loading emptydata not yet supported...";
    }

    if (defined $outdata) {
	$self->{Object} = $outdata;
	$self->{Type}   = 'content';
    } elsif (defined $emptydata) {
	$self->{Object} = eval $emptydata; # XXX should use Safe!
	$self->{Type}   = 'template';
    } else {
	die "No data found!";
    }

    $self->{Object};
}

sub serialize {
    my $self = shift;
    if (!$self->{P}) { $self->_create_parser() }
    my $xml = '<?xml version="1.0" encoding="utf-8"?>' . $self->{P}->pl2xml($self->{Object});
    if      ($self->_can_XML_LibXSLT) {
	$xml = $self->_beautify_with_XML_LibXSLT($xml);
    } elsif ($self->_can_XML_XSLT) {
	$xml = $self->_beautify_with_XML_XSLT($xml);
    }
    $xml;
}

sub ext { "xml" }

sub _can_XML_XSLT {
    my $self = shift;
    warn "Can't use the identity idiom with XML::XSLT (yet)";
    return 0;
    eval { require XML::XSLT; 1 };
}

sub _beautify_with_XML_XSLT {
    my($self, $xml) = @_;
    my $xslt = XML::XSLT->new($self->stylesheet);
    $xslt->transform($xml);
    $xml = $xslt->toString;
    $xslt->dispose;
    $xml;
}

sub _can_XML_LibXSLT {
    my $self = shift;
    eval {
	require XML::LibXML;
	require XML::LibXSLT;
	1;
    };
}

sub _beautify_with_XML_LibXSLT {
    my($self, $xml) = @_;

    my $parser = XML::LibXML->new();
    my $xslt = XML::LibXSLT->new();

    my $source = $parser->parse_string($xml);
    my $style_doc = $parser->parse_string($self->stylesheet);

    my $stylesheet = $xslt->parse_stylesheet($style_doc);

    my $results = $stylesheet->transform($source);

    $stylesheet->output_string($results);
}

sub stylesheet {
    <<'EOF';
<?xml version="1.0" encoding="iso-8859-1"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
 <xsl:template match="@memory_address" />
 <xsl:template match="@*|node()">
  <xsl:copy>
   <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
 </xsl:template>
</xsl:stylesheet>
EOF
}

1;

__END__

=head1 NAME

WE_Content::XML - web.editor content in XML files

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 HISTORY

Versions until 1.03 used to use L<XML::Simple>. Now the module uses
L<XML::Dumper>, because XML::Simple is not able to reliable serialize
and deserialize data, as stated by the XML::Simple author.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Base>, L<XML::Dumper>.

=cut

