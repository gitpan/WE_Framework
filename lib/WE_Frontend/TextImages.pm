# -*- perl -*-

#
# $Id: TextImages.pm,v 1.4 2003/02/12 10:12:43 eserte Exp $
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

package WE_Frontend::TextImages;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base 'Exporter';
@EXPORT_OK = qw(text2gif);

use GD;
BEGIN {
    if (!eval 'use GD::Convert qw(gif=any); 1') {
	warn "GD::Convert is not installed --- gif method probably not available. Error was: $@";
    }
}

sub text2gif {
    my(%args) = @_;

    my $o_file = delete $args{-o};

    my $text_color = delete $args{-c};
    $text_color = "000000" if !defined $text_color;
    my $bg_color   = delete $args{-b};
    $bg_color   = "FFFFFF" if !defined $bg_color;
    my $font_file  = delete $args{-f};
    die "Font file -f not specified" if !defined $font_file;

    my $font_size  = delete $args{-s} || 16;
    my $leading    = delete $args{-l} || 0;
    my $bl         = delete $args{-bl} || 0;
    my $bt         = delete $args{-bt} || 0;
    my $br         = delete $args{-br} || 0;
    my $bb         = delete $args{-bb} || 0;

    my $width      = delete $args{-width};
    my $height     = delete $args{-height};

    my $text       = delete $args{-text};
    if (!defined $text) {
	warn "-text not specified";
    }

    my $dummy = GD::Image->new(1,1);
    my $bg = $dummy->colorAllocate(map { hex($_) } $bg_color =~ /(..)(..)(..)/);
    my $fg = $dummy->colorAllocate(map { hex($_) } $text_color =~ /(..)(..)(..)/);
    my @bounds = GD::Image->stringTTF($fg, $font_file, $font_size, 0, $leading, 0, $text);

    my $need_width  = $bl+$br+($bounds[2]-$bounds[0]);
    my $need_height = $bt+$bb+($bounds[3]-$bounds[7]);

    my $im;
    if (defined $width && defined $height) {
	if ($width < $need_width) {
	    warn "Width $need_width needed, but only $width specified\n";
	}
	if ($height < $need_height) {
	    warn "Height $need_height needed, but only $height specified\n";
	}
	$im = GD::Image->new($width, $height);
    } else {
	$im = GD::Image->new($need_width, $need_height);
    }
    $bg = $im->colorAllocate(map { hex($_) } $bg_color =~ /(..)(..)(..)/);
    $fg = $im->colorAllocate(map { hex($_) } $text_color =~ /(..)(..)(..)/);
    $im->transparent($bg);

    @bounds = $im->stringTTF($fg, $font_file, $font_size, 0, $leading+$bl, -$bounds[7]-1+$bt, $text);

    #$GD::Convert::DEBUG=1;
    my $gif = $im->gif(-transparencyhack => 1);

    my %ret;

    if (defined $o_file) {
	open(GIF, ">$o_file") or die "Can't write to $o_file: $!";
	binmode GIF;
	print GIF $gif;
	close GIF;
    } else {
	$ret{Image} = $gif;
    }
    $ret{Bounds} = \@bounds;

    %ret;
}

return 1 if caller;

text2gif(@ARGV);

__END__

=head1 NAME

WE_Frontend::TextImages - create text images

=head1 SYNOPSIS

    use WE_Frontend::TextImages qw(text2gif);

    text2gif(qw(-o /tmp/test.gif
		-c 000000
		-b FFFFFF
		-f font.ttf
		-s 10
		-l 0
		-bl 0 -bt 0 -br 0 -bb 0
		-text test_string));

=head1 DESCRIPTION

This module contains function for creating images with text.

=head2 text2gif

C<text2gif> is a function to create a text image file. The following
options are supported:

=over 4

=item -o filename

If specified, the put the generated GIF file into the filename.
Otherwise the image is available in the return value (see below).

=item -c color

Text color as rrggbb. Example: 'FF0000' for full red. Default:
'000000' (black).

=item -b color

Background color as rrggbb. Default: 'FFFFFF' (white).

=item -f file.ttf

Font file (e.g. timesbd.ttf). There is no default.

=item -s size

Font size in pixels. Default: '16'.

=item -l pixels

Leading (distance from left border) in pixels.

=item -bl pixels

Size of left border. Default: 0.

=item -bt pixels

Size of top border. Default: 0.

=item -br pixels

Size of right border. Default: 0.

=item -bb pixels

Size of bottom border. Default:0.

=item -width pixels

Width of the generated picture. This is optional, normally the width
is calculated by the text width and used borders.

=item -height pixels

Height of the generated picture. This is optional, normally the height
is calculated by the text height and used borders.

=item -text text

The generated text.

=back

=head2 RETURN VALUE

The function returns a hash with the following keys:

=over 4

=item Image

(Only if C<-o> is not specified). The GIF image as a string.

=item Bounds

An array of the bounding coordinates. See the C<getBounds> method in
L<GD> for the exact format.

=back

=head1 CAVEATS

Please note that the C<PATH> variable in CGI scripts is normally
crippled to something like C</bin:/usr/bin>. You have to add the path
containing C<ppmtogif> or C<convert> (maybe C</usr/local/bin>) to make
the gif conversion in C<GD::Convert> work:

    BEGIN { $ENV{PATH} .= ":/usr/local/bin" }
    use WE_Frontend::TextImages qw(text2gif);

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

