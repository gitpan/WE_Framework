# -*- perl -*-

#
# $Id: YAML.pm,v 1.7 2003/12/16 15:21:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Content::YAML;
use base qw(WE_Content::Base);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use YAML ();
YAML->VERSION(0.30); # YAML::Dump

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

    my $emptydata;
    my $outdata = eval { local $SIG{__DIE__}; YAML::Load($buf) };
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
    YAML::Dump($self->{Object});
}

sub ext { "yml" }

1;

__END__

=head1 NAME

WE_Content::YAML - web.editor content in YAML files

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Base>, L<YAML>.

=cut

