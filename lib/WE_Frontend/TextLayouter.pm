# -*- perl -*-

#
# $Id: TextLayouter.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package WE_Frontend::TextLayouter;

use strict;
use vars qw($VERSION %fontinfo @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base 'Exporter';
@EXPORT_OK = qw(break_text continue_text_with_nl combine_fontinfo);

sub break_text {
    my($text, $fontinfo, $boxwidth, $boxheight, %args) = @_;

    my @out;
    my $box           = $args{'-box'}; $box = "" if !defined $box;
    my $x             = $args{'-x'} || 0;
    my $y             = $args{'-y'} || 0;
    my $maxlineheight = $args{'-maxlineheight'} || 0;
    my $lastboxref    = $args{'-lastbox'};

    my $space_width = (get_bounds(" ", $fontinfo))[0];
    my $line_height = (get_bounds("A", $fontinfo))[1]; # XXX maybe better character than "A"?

    foreach my $line (split /\n/, $text) {

	my $push_word;
	my $word_height = 0;

	my $next_line_or_box = sub {
	    if ($y+$word_height+$maxlineheight >= $boxheight) {
		# next box
		push @out, $box;
		$box = "";
		$x = 0;
		$y = 0;
		$maxlineheight = 0;
		$push_word->() if $push_word;
	    } else {
		# next line
		$box .= "\n";
		$x = 0;
		$y += $maxlineheight;
		$maxlineheight = 0;
		$push_word->() if $push_word;
	    }
	};

	foreach my $word (split /\s+/, $line) {
	    my $word_width;
	    ($word_width, $word_height) = get_bounds($word, $fontinfo);

	    my $is_beginning_of_line = sub {
		$box eq '' || $box =~ /\n\Z/s;
	    };

	    $push_word = sub {
		if (!$is_beginning_of_line->()) {
		    $box .= " ";
		    $x += $space_width;
		}
		$box .= $word;
		$x += $word_width;
		if ($word_height > $maxlineheight) {
		    $maxlineheight = $word_height;
		}
	    };

	    my $this_space_width = (!$is_beginning_of_line->() ? $space_width : 0);

	    if ($x+$word_width+$this_space_width < $boxwidth &&
		$y+$word_height < $boxheight) {
		# fits into this line
		$push_word->();
	    } else {
		$next_line_or_box->();
	    }
	}

	undef $push_word;
	$maxlineheight = $line_height;
	$next_line_or_box->();
    }

    push @out, $box if $box ne "";

    if ($lastboxref) {
	$lastboxref->{'-box'}           = $box;
	$lastboxref->{'-x'}             = $x;
	$lastboxref->{'-y'}             = $y;
	$lastboxref->{'-maxlineheight'} = $maxlineheight;
    }

    @out;
}

#XXX
#  sub add_br {
#      my($fontinfo, $boxwidth, $boxheight, %args) = @_;
#      if (!$args{'-prevlastbox'}) {
#  	die "The -prevlastbox option is missing";
#      }
#      my $prevlastbox = delete $args{'-prevlastbox'};
#      my %new_args = (-box => $prevlastbox->{'-box'}."<br>\n",
#  		    -x => 0,
#  		    -y => $prevlastbox->{'-maxlineheight'}+$prevlastbox->{'-y'});
#      break_text("", $fontinfo, $boxwidth, $boxheight, %args, %new_args);
#  }

###XXX hmmm...????
sub continue_text_with_nl {
    my($text, $fontinfo, $boxwidth, $boxheight, %args) = @_;
    if (!$args{'-prevlastbox'}) {
	die "The -prevlastbox option is missing";
    }
    my $prevlastbox = delete $args{'-prevlastbox'};
    my %new_args = (-box => $prevlastbox->{'-box'}.($prevlastbox->{'-box'}ne""?"\n":""),
		    -x => 0,
		    -y => $prevlastbox->{'-maxlineheight'}+$prevlastbox->{'-y'});
    break_text($text, $fontinfo, $boxwidth, $boxheight, %args, %new_args);
}

sub add_y {
    my($prevlastbox_ref, $yadd) = @_;
    $prevlastbox_ref->{'y'} = 0 if !$prevlastbox_ref->{'y'};
    $prevlastbox_ref->{'y'} += $yadd;
}

sub get_bounds {
    my($text, $fontinfo) = @_;
    my($x,$y) = (0,0);

    foreach my $ch (split //, $text) {
	my $ord = ord $ch;
	if ($ord >= $fontinfo->{'firstchar'} &&
	    $ord <= $fontinfo->{'lastchar'}) {
	    my $inx = $ord-$fontinfo->{'firstchar'};
	    $x += $fontinfo->{'widths'}[$inx];
	    my $chheight = $fontinfo->{'heights'}[$inx];
	    if ($chheight > $y) {
		$y = $chheight;
	    }
	}
    }

    ($x,$y);
}

1;

__END__

=head1 NAME

WE_Frontend::TextLayouter - support functions for layouting text and html

=head1 SYNOPSIS

    use WE_Frontend::TextLayouter qw(break_text);
    my(@text_blocks) = break_text($text, $fontinfo, $boxwdith, $boxheight);

=head1 DESCRIPTION

This module supplies some support functions for layouting text and
html.

=head2 FUNCTIONS

=over 4

=item break_text($text, $fontinfo, $boxwidth, $boxheight, %args)

Takes a string parameter C<$text> with plain text and breaks this text
into several parts (returned as a list of text strings) according to
C<$fontinfo> and a box with the dimensions C<$boxwidth> and
C<$boxheight>.

See L<WE_Frontend::FontInfo> for more information about the
C<$fontinfo> structure.

Optionally, additional arguments can be supplied if a partially filled
boxed should be filled further:

=over 4

=item -box => $string

The partially filled box (default: empty).

=item -x => $x

The starting x coordinate (default 0).

=item -y => $y

The starting y coordinate (default 0).

=item -maxlineheight => $y

The height of the current line.

=item -lastbox => $hashref

The -lastbox hash reference, if specified, will be filled with the
last values for C<-x>, C<-y>, C<-maxlineheight> and C<-box> for the
last box.

=back

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Frontend::FontInfo>

=cut

