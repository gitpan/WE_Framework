# -*- perl -*-

#
# $Id: PerlDD.pm,v 1.7 2004/04/14 21:23:51 eserte Exp $
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

package WE_Content::PerlDD;
use base qw(WE_Content::Base);

use strict;
use vars qw($VERSION $consider_safe);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

$consider_safe = 0 if !defined $consider_safe;

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
    $self;
}

sub parse {
    my($self, %args) = @_;
    my $buf = $self->get_string(%args);

    use vars qw($outdata $emptydata);
    $outdata = $emptydata = undef;

    if ($consider_safe) {
	eval $buf;
	if ($@) {
	    my $line = 1;
	    warn join("\n", map { sprintf("%3d: %s", $line++, $_) } split /\n/, $buf);
	    die $@;
	}
    } else {
	require Safe;
	undef $WE_Content::PerlDD::Safe::outdata;
	undef $WE_Content::PerlDD::Safe::emptydata;
	my $s = Safe->new("WE_Content::PerlDD::Safe");
	$s->reval($buf);
	if ($@) {
	    my $line = 1;
	    warn join("\n", map { sprintf("%3d: %s", $line++, $_) } split /\n/, $buf);
	    die $@;
	}
	if (defined $WE_Content::PerlDD::Safe::outdata) {
	    $outdata = $WE_Content::PerlDD::Safe::outdata;
	} elsif (defined $WE_Content::PerlDD::Safe::emptydata) {
	    $emptydata = $WE_Content::PerlDD::Safe::emptydata;
	}
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
    require Data::Dumper;
    my $dd = Data::Dumper->new([$self->{Object}], ['outdata']);
    if ($^O eq 'MSWin32') {
	$dd->Indent(0); # to prevent a memory leak in ActivePerl 5.6.1
    } else {
	$dd->Indent(1);
    }
    $dd->Dump;
}

sub ext { "pl" }

1;

__END__

=head1 NAME

WE_Content::PerlDD - web.editor content in perl data dumper files

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Base>.

=cut

