# -*- perl -*-

#
# $Id: Base.pm,v 1.14 2005/05/13 09:53:13 eserte Exp $
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

package WE_Content::Base;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($self, %args) = @_;
    my $buf = $self->get_string(%args);
    my $class = $self->guess_class($buf);
    my %newargs = %args;
    delete $newargs{$_} for ("-string", "-file");
    $newargs{-string} = $buf;
    $class->new(%newargs);
}

sub debug {
    my $self = shift;
    if (@_) {
	$self->{Debug} = $_[0];
    }
    $self->{Debug};
}

sub clone {
    my($self, $as) = @_;
    require Data::Dumper;
    my $o;
    eval Data::Dumper->new([$self],['o'])->Indent(0)->Purity(1)->Dump;
    die $@ if $@;
    if (defined $as) {
	bless $o, $as;
    }
    $o;
}

sub get_string {
    my($self, %args) = @_;
    my($buf);
    if ($args{-file}) {
	open(F, "< $args{-file}") or die "Can't read $args{-file}: $!";
	local $/ = undef;
	$buf = <F>;
	close F;
    } elsif ($args{-string}) {
	$buf = $args{-string};
    } else {
	die "Either -string or -file must be specified";
    }
    $buf;
}

sub guess_class {
    my($self, $buf) = @_;
    if ($buf =~ /^---( \#YAML:)?/) {
	require WE_Content::YAML;
	'WE_Content::YAML';
    } elsif ($buf =~ /^<\?xml/) {
	if ($buf =~ /<webeditordoc/) {
	    require WE_Content::XMLText;
	    'WE_Content::XMLText';
	} else {
	    require WE_Content::XML;
	    'WE_Content::XML';
	}
    } else {
	require WE_Content::PerlDD;
	'WE_Content::PerlDD';
    }
}

sub _by_path {
    my $self = shift;
    my $path = shift;
    my $sep = shift;
    my $do_set;
    my $value;
    if (@_) {
	$do_set = 1;
	$value = shift;
    }
    my $o = $self->{Object};
    return undef if !$o;
    my $o_ref = \$o;
    my @path;
    $sep = "/" if !defined $sep;
    my $sep_rx = quotemeta $sep;
    if (UNIVERSAL::isa($path, 'ARRAY')) {
	@path = @$path;
    } else {
	$path =~ s|^$sep_rx/+||;
	@path = split $sep_rx, $path;
    }
    foreach my $p (@path) {
	if (UNIVERSAL::isa($o, 'ARRAY')) {
	    if (defined $o->[$p]) {
		$o_ref = \$o->[$p];
		$o = $o->[$p];
	    } else {
		if ($do_set) {
		    die "Can't set $path to $value";
		}
		return undef;
	    }
	} elsif (UNIVERSAL::isa($o, 'HASH')) {
	    if (exists $o->{$p}) {
		$o_ref = \$o->{$p};
		$o = $o->{$p};
	    } else {
		if ($do_set) {
		    die "Can't set $path to $value";
		}
		return undef;
	    }
	} else {
	    die "Can't handle " . ref($o) . " ($o) from path @path";
	}
    }
    if ($do_set) {
	$$o_ref = $value;
    }
    $o;
}

sub by_path   { shift->_by_path(@_, "/") }
sub by_dotted { shift->_by_path(@_, ".") }
sub set_by_path   { shift->by_path(shift, "/", @_) }
sub set_by_dotted { shift->by_dotted(shift, ".", @_) }

# "prototype": new name, "template": old name
sub is_prototype {
    $_[0]->{Type} eq 'template';
}

sub serialize_as {
    my $self = shift;
    my $as   = shift;
    if ($as !~ /^WE_Content::/) {
	$as = "WE_Content::$as";
    }
    eval "require $as";
    die $@ if $@;
    require Storable;
    my $clone = Storable::dclone($self);
    bless $clone, $as; # re-bless
    $clone->serialize(@_);
}

1;

__END__

=head1 NAME

WE_Content::Base - base class for all web.editor content implementations

=head1 SYNOPSIS

    use WE_Content::Base;

=head1 DESCRIPTION

=head2 CONSTRUCTOR

    new WE_Content::... -string => ..., -file => ..., -object => ...

Construct with either a string, content from file or a perl object.

=head2 METHODS

=over

=item clone([$as])

Clone the C<$self> object. If C<$as> is supplied, then the cloned
object is blessed to this class.

=item get_string([-file => ... | -string => ...])

Get a string either from file or from string.

=item guess_class($buf)

Guess the C<WE_Content::...> implementation of the data in C<$buf>.
Currently C<WE_Content::YAML> or C<WE_Content::PerlDD> may be
returned.

=item by_path($path)

Return the referenced content element. The path is either a string
with "/" as path separator or an array reference. Leading "/" are
optional.

=item by_dotted($path)

Same as by_path, but use the dot (".") as separator.

=item set_by_path($path, $new_value)

Set the referenced (scalar) path to C<$new_value>.

=item set_by_dotted($path, $new_value)

Same as set_by_path, but use the dot (".") as separator.

=item set_by_dotted($path, $value)

=item is_prototype

Return true, if the current object is from "prototype" or "template"
type.

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Tools>, L<WE_Content::PerlDD>.

=cut

