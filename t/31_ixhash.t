#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 31_ixhash.t,v 1.2 2002/09/11 15:50:39 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN {
    if (!eval q{
	use Tie::IxHash;
	1;
    }) {
	print "1..0 # skip: no Tie::IxHash module\n";
	exit;
    }
}

BEGIN {
    if (!eval q{
	die;
	1;
    }) {
	print "1..0 # skip: unusable because of Data::Dumper bugs\n";
	exit;
    }
}

use WE_Content::IxHash;
use Data::Dumper;

BEGIN { plan tests => 12 }

{
    my $a = ["null",
	     OH(bla => "foo",
		bar => "4711",
		xyz => "42",
	       ),
	     "eins"];
    my $ref = $a->[1];
    ok(ref(tied %$ref), 'WE_Content::IxHash');
    ok(UNIVERSAL::isa((tied %$ref), 'Tie::IxHash'));
    ok(UNIVERSAL::isa($ref, "HASH"));
    ok(join("#", keys %$ref), "bla#bar#xyz");
    ok(scalar each %$ref, "bla");

    my($ddvar, $new_ref);
    {
	local $Data::Dumper::Toaster = 'thaw';
	local $Data::Dumper::Freezer = 'freeze';
	$new_ref = eval Data::Dumper->new([$ref],['ddvar'])->Dumpxs;
warn $new_ref;
	die $@ if $@;
    }
    ok(join("#", keys %$new_ref), "bla#bar#xyz");

}

{
    my $oh = OH;
    ok(ref(tied %$oh), 'WE_Content::IxHash');

    my @added;
    for (1..1) {
	my $key = join("", map { chr(int(rand(64))+32) } (1..10));
	$oh->{$key} = $_;
	push @added, $key;
    }

    ok(scalar keys %$oh, scalar @added);
    ok(join("#", keys %$oh), join("#", @added));

    my($ddvar, $new_ref);
    {
	local $Data::Dumper::Toaster = 'thaw';
	local $Data::Dumper::Freezer = 'freeze';
	$ddvar = Data::Dumper->new([$oh],['ddvar'])->Useperl(0)->Dump;
	$new_ref = eval $ddvar;
	die $@ if $@;
    }
    ok(join("#", keys %$new_ref), join("#", @added));

}

{
    my $oh = OH(abc=>"def");
    $oh->{geh} = "ijk";
    $oh->{lmn} = "opq";
    ok(join("#", keys %$oh), "abc#geh#lmn");

    my($dd, $ddvar);
    $dd = WE_Content::IxHash::DD_new($oh, 'ddvar');
    $ddvar = $dd->Dump;
    my $new_ref = eval $ddvar;
    ok(join("#", keys %$new_ref), "abc#geh#lmn");
}

__END__
