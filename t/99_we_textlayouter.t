#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 99_we_textlayouter.t,v 1.2 2004/03/30 10:05:10 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use WE_Frontend::TextLayouter qw(break_text continue_text_with_nl);
use WE_Frontend::FontInfo;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 4 }

my $fontinfo_linux = # {'LinuxELF2.2'}{'Netscape'}{'sans-serif'}{'12px'}
{
 firstchar => 32,
 lastchar => 255,
 widths =>
 [3,3,4,6,6,9,8,3,4,4,4,6,3,7,3,3,6,6,6,6,6,6,6,6,6,6,3,3,6,5,6,6,11,7,7,8,8,7,6,8,8,3,5,7,6,9,8,8,7,8,7,7,5,8,7,9,7,7,7,3,3,3,6,6,3,5,6,5,6,5,4,6,6,2,2,5,2,8,6,6,6,6,4,5,4,5,6,8,6,5,5,3,3,3,7,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,3,3,6,6,5,6,3,6,3,9,4,6,7,4,9,3,4,6,3,3,3,5,6,3,3,3,4,6,9,9,9,6,7,7,7,7,7,7,10,8,7,7,7,7,3,3,3,3,8,8,8,8,8,8,8,6,8,8,8,8,8,7,7,5,5,5,5,5,5,5,8,5,5,5,5,5,2,2,2,2,6,5,6,6,6,6,6,6,6,5,5,5,5,5,6,5],
 heights =>
 [12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12],
};

my $new_fi = combine_fontinfo($fontinfo_linux);
is(join(",",@{$fontinfo_linux->{widths}}), join(",",@{$new_fi->{widths}}),
   "fontinfo check (linux)");

my $fontinfo_win32 = #{'Win32'}{'Netscape'}{'sans-serif'}{'12px'}
{
 firstchar => 32,
 lastchar => 255,
 widths =>
[3,3,4,7,7,11,8,2,4,4,5,7,3,4,3,3,7,7,7,7,7,7,7,7,7,7,3,3,7,7,7,7,12,7,8,9,9,8,7,9,9,3,6,8,7,9,9,9,8,9,9,8,7,9,7,11,7,7,7,3,3,3,5,7,4,7,7,6,7,7,3,7,7,3,3,6,3,11,7,7,7,7,4,7,3,7,5,9,5,5,5,4,3,4,7,9,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,3,3,7,7,7,7,3,7,4,9,4,7,7,4,9,7,5,7,4,4,4,7,6,3,4,4,4,7,10,10,10,7,7,7,7,7,7,7,12,9,8,8,8,8,3,3,3,3,9,9,9,9,9,9,9,7,9,9,9,9,9,7,8,8,7,7,7,7,7,7,11,6,7,7,7,7,3,3,3,3,7,7,7,7,7,7,7,7,7,7,7,7,7,5,7,5],
 heights =>
[15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15],
};

$new_fi = combine_fontinfo($fontinfo_win32);
is(join(",",@{$fontinfo_win32->{widths}}), join(",",@{$new_fi->{widths}}),
   "fontinfo check (win32)");

$new_fi = combine_fontinfo($fontinfo_win32, $fontinfo_linux);

#my $fontinfo = $fontinfo_win32;
#my $fontinfo = $new_fi;
my $fontinfo = $fontinfo_linux;

my $lastbox = {};

my $sample_text = <<EOF;
Tokyo telephoned umpteen obese aardvarks. Five botulisms ran away
drunkenly, and the irascible fountains gossips cleverly, because one
slightly silly chrysanthemum easily telephoned five orifices.
Very schizophrenic fountains comfortably perused two progressive
chrysanthemums, and obese pawnbrokers grew up noisily, though one
bureau towed five putrid orifices, because one mostly obese
Jabberwocky gos-sips easily.
EOF

if (eval { require Text::Lorem; 1 }) {
    $sample_text = "Sample text using Text::Lorem: " . Text::Lorem->new->paragraphs(1);
}

my @out = break_text($sample_text,$fontinfo,200,100,-lastbox => $lastbox);

is(join(" ", split /\n/, $sample_text),
   join(" ", map { split /\n/, $_ } @out), "break text");

# add something to the last box
@out = continue_text_with_nl($sample_text,$fontinfo,200,100,
			     -prevlastbox => $lastbox);

my $out_str = join(" ", map { split /\n/, $_ } @out);
$out_str =~ s/ +/ /g;
is(join(" ", split /\n/, "$lastbox->{-box}$sample_text"),
   $out_str, "continue text");

#  # again, but now force one newline:
#  my $newlastbox = {};
#  continue_text_with_br($sample_text,$fontinfo,200,100,
#  		      -prevlastbox => $lastbox,
#  		      -lastbox => $newlastbox);
#  @out = continue_text_with_br($sample_text,$fontinfo,200,100,
#  			     -prevlastbox => $newlastbox);

#  foreach my $out (@out) {
#      print "$out\n\n";
#  }
#ok(1);

__END__
