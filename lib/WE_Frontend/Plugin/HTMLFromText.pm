# -*- perl -*-

#
# $Id: HTMLFromText.pm,v 1.5 2004/01/12 16:21:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::HTMLFromText;
use base qw(Template::Plugin);

use HTML::Entities;
use HTML::FromText;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub fixeol ($);

=head1 NAME

WE_Frontend::Plugin::HTMLFromText - format a textual table description to HTML

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE HTMLFromText %]
    [% HTMLFromText.out(textdef) %]

=head1 DESCRIPTION

This plugin feeds the textdef object to L<HTML::FromText>. The B<opts>
member can be set a list of decorators and output modes.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context) = @_;
    my $self = {Context => $context};
    bless $self, $class;
}

=item out($textdef)

Format and output the given text definition.

=cut

sub out {
    my($self, $textdef) = @_;
    my $type  = $textdef->{type};
    if ($type ne "autoformattext") {
	warn "Element type is `$type', expected `autoformattext'";
    }
    my $opts = $textdef->{opts}||"";
    my $text = fixeol $textdef->{text};
    my %std_opts = map {($_,1)} split /,/, "urls,email,bold,underline,paras,bullets,numbers,tables";
    my %opts;
    my @set_opts = split /,/, $opts;
    if (!grep { /^[^\+\-]/ } @set_opts) {
	%opts = %std_opts;
    } else {
	warn "Do not set options";
    }
    for my $opt_def (@set_opts) {
	if ($opt_def =~ /^-(.*)/) {
	    delete $opts{$1};
	} elsif ($opt_def =~ /^\+?(.*)/) {
	    $opts{$1} = 1;
	}
    }

    return text2html($text, %opts);
}

sub fixeol ($) {
    my $s = shift;
    $s =~ s/\015//g;
    $s;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>, L<HTML::FromText>.

=cut

