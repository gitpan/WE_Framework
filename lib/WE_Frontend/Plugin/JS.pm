# -*- perl -*-

#
# $Id: JS.pm,v 1.7 2004/12/12 11:40:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Frontend::Plugin::JS;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use base qw(Template::Plugin);

sub new {
    my($class, $context, @args) = @_;
    WE_Frontend::Plugin::JS::Quote->new($context, @args);
    WE_Frontend::Plugin::JS::QuoteUnicode->new($context, @args);
    WE_Frontend::Plugin::JS::Escape->new($context, @args);
    bless {}, $class;
}

######################################################################

package WE_Frontend::Plugin::JS::Quote;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

use vars qw(%repl $repl_keys $rx);
%repl = (
	 "\\" => "\\\\",
	 "\"" => "\\\"",
	 "\'" => "\\\'",
	 "\n" => "\\n",
	 "\r" => "\\r",
	 "\b" => "\\b",
	 "\f" => "\\f",
	 "\t" => "\\t",
	);
for(0 .. 31) {
    if (!exists $repl{chr($_)}) {
	$repl{chr($_)} = "\\" . sprintf("%03o", $_);
    }
}
$repl_keys = "(" . join("|", map { quotemeta } keys %repl) . ")";
$rx = qr/$repl_keys/;

sub init {
    my $self = shift;
    $self->install_filter("js_q");
    $self;
}

sub filter {
    my($self, $text) = @_;
    $text =~ s/$rx/$repl{$1}/g;
    $text;
}

######################################################################

package WE_Frontend::Plugin::JS::QuoteUnicode;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

use vars qw(%repl $repl_keys $rx);
%repl = (
	 "\\" => "\\\\",
	 "\"" => "\\\"",
	 "\'" => "\\\'",
	 "\n" => "\\n",
	 "\r" => "\\r",
	 "\b" => "\\b",
	 "\f" => "\\f",
	 "\t" => "\\t",
	);
for(0 .. 31) {
    if (!exists $repl{chr($_)}) {
	$repl{chr($_)} = "\\" . sprintf("%03o", $_);
    }
}
$repl_keys = "(" . join("|", (map { quotemeta } keys %repl), "[\x7f-\x{fffd}]") . ")";
$rx = qr/$repl_keys/;

sub init {
    my $self = shift;
    $self->install_filter("js_uni");
    $self;
}

sub filter {
    my($self, $text) = @_;
    $text =~ s/$rx/exists $repl{$1} ? $repl{$1} : sprintf "\\u%04x", ord($1)/ge;
    $text;
}

######################################################################

package WE_Frontend::Plugin::JS::Escape;
use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
#use URI::Escape qw(uri_escape);

sub init {
    my $self = shift;
    $self->install_filter("js_escape");
    $self;
}

sub filter {
    my($self, $text) = @_;
    #uri_escape($text, "^A-Za-z0-9");
    $text =~ s{ ([^A-Za-z0-9]) }
	      { ord($1) > 255 ? sprintf "%%u%04x", ord $1
		              : sprintf "%%%02x", ord $1
              }gex;
    $text;
}

1;

__END__

=head1 NAME

WE_Frontend::Plugin::JS - filters for quoting and escaping javascript

=head1 SYNOPSIS

In a template:

    [% USE JS %]
    var foo = "[% variable | js_q %]";
    var bar = unescape("[% variable | js_escape %]");

=head1 DESCRIPTION

This package contains to filters to make supplied variables safe for
inclusion as a javascript string. The two available filters are
B<js_q>, which escapes special characters with backslashes, and
B<js_escape>, which creates a UTI-escaped string which has to be
unescaped with javascript's B<unescape> function.

=head1 AUTHOR

Slaven Rezic

=cut
