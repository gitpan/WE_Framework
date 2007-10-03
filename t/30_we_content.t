#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 30_we_content.t,v 1.19 2007/10/03 08:29:33 eserte Exp $
# Author: Slaven Rezic
#

# XXX Some tests will probably fail on non-Unicode-aware perls

use strict;

use WE_Content::PerlDD;
use WE_Content::Tools;
use FindBin;
use Data::Dumper;

use vars qw($yaml_tests $xml_tests);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "# tests only work with installed Test::More module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    $yaml_tests = 7;
    $xml_tests  = 16;
}

BEGIN { plan tests => 33*2 + $yaml_tests + $xml_tests*2 }

my $contentdir = "$FindBin::RealBin/content";
my $clone;

for my $class ('WE_Content::PerlDD', 'WE_Content::Base') {
    my $content = $class->new(-file => "$contentdir/sample_content.bin");
    is($content->isa("WE_Content::PerlDD"), 1, "Check isa of $class");
    is($content->isa("WE_Content::Base"), 1);
    is($content->{Type}, "content");

    my $template = $class->new(-file => "$contentdir/empty_product.bin");
    is($template->isa("WE_Content::PerlDD"), 1);
    is($template->{Type}, "template");

    is($template->by_path('title'), 'neue Produktseite', "Check by_path");
TODO: { local $TODO = "Why is this one failing?";
    is($template->by_path('/title'), 'neue Produktseite');
}
    is($template->by_path('/////title'), 'neue Produktseite');
    is($template->by_path('ct/0/cancontain/0'), 'textblock');
    is($template->by_path('ct/0/cancontain/2'), undef);
    is($template->by_path(["ct", 1, 'cancontain', 0]), "link");

 SKIP: {
	skip "No Algorithm::Diff", 3
	    unless (eval {
		require Algorithm::Diff;
		require Data::Dumper;
		Data::Dumper->VERSION(2.121); # SortKeys
		1;
	    });
	my(%diffs) = $content->get_structure_diffs($template);
	{
	    local $TODO = "The semantics of get_structure_diffs changed";
	    is(scalar @{$diffs{'de'}}, 0, "get_structure_diffs"); #, Dumper($diffs{'de'}));
	}
	is(scalar @{$diffs{'en'}}, 0); #, Dumper($diffs{'de'}));

	%diffs = $template->get_structure_diffs($template);
	is(scalar keys %diffs, 0);
    }

    $clone = $content->clone;
    is($clone->isa("WE_Content::PerlDD"), 1, "clone is still a PerlDD object");

 SKIP: {
	skip "No Algorithm::Diff", 4
	    unless (eval { require Algorithm::Diff; 1 });
	my(%diffs) = $clone->get_structure_diffs($template);
	{
	    local $TODO = "The semantics of get_structure_diffs changed";
	    is(scalar @{$diffs{'de'}}, 0);
	}
	is(scalar @{$diffs{'en'}}, 0);
	is($content->simple_diff($content), 0);
	is($clone->simple_diff($content), 0);
    }

    $clone->{Object}->{'data'}->{'pageid'} = 15;
    is($clone->{Object}->{'data'}->{'pageid'},15);
    is($content->{Object}->{'data'}->{'pageid'},14);

 SKIP: {
	skip "No Algorithm::Diff", 2
	    unless (eval { require Algorithm::Diff; 1 });
	is(scalar $clone->simple_diff($content), 1);
	is(scalar $content->simple_diff($clone), 1);
    }

    my %types;
    $clone->find(sub { my($o, %args) = @_;
		       if ($args{-key} && $args{-key} eq 'type') {
			   $types{$o}++;
		       }
		   });
    foreach (qw(text free textblock imageblock)) {
	ok(exists $types{$_}, "find $_");
    }
    is($types{'free'}, 6);
    is($types{'text'}, 1);
    is(scalar keys %types, 4);

    my $path;
    $clone->find(sub {
        my($o, %args) = @_;
	if ($args{-key} && $args{-key} eq 'type' && $o eq 'text') {
	    if (defined $path) {
		die "There should be only one text element in the data structure";
	    }
	    $path = $args{-path};
	}});
    is($path, "->{'data'}->{'de'}->{'ct'}->[0]->{'ct'}->[0]->{'ct'}->[0]->{'type'}");

    ok(cancontain_boldtext($clone));

    # remove boldtext from cancontain
    $clone->find(sub {
        my($o, %args) = @_;
	if ($args{-key} && $args{-key} eq 'cancontain') {
	    my(%cancontain) = map { ($_ => 1) } @$o;
	    if ($cancontain{'boldtext'}) {
		for(my $i=0; $i<=$#$o; $i++) {
		    if ($o->[$i] eq 'boldtext') {
			splice @$o, $i, 1;
			$i--;
		    }
		}
	    }
	}
    });

    is(cancontain_boldtext($clone), 0);
}

SKIP: {
    skip "No YAML installed", $yaml_tests
	unless (eval { require YAML; YAML->VERSION(0.30) }); # YAML::Dump
    require WE_Content::YAML;
    my $yaml_clone = $clone->clone('WE_Content::YAML');
    ok($yaml_clone->isa('WE_Content::YAML'), "a WE_Content::YAML object");
    ok($yaml_clone->isa('WE_Content::Base'), "expected base class");
    my $yaml = $yaml_clone->serialize;
    like($yaml, qr/^---( \#YAML)?/, "Has a YAML header");
    my $yaml_new = WE_Content::YAML->new(-string => $yaml);
    ok($yaml_new->isa('WE_Content::YAML'), "still a WE_Content::YAML object");
    my $yaml2 = $yaml_new->serialize;
    is($yaml, $yaml2, "both YAML objects are the same");
    $yaml_new = WE_Content::Base->new(-string => $yaml);
    ok($yaml_new->isa('WE_Content::YAML'));
    $yaml2 = $yaml_new->serialize;
    is($yaml, $yaml2);
}

for my $modulebase (qw(XML XMLText)) {
 SKIP: {
	skip("Some tests fail with XMLText TODO", $xml_tests)
	    if $modulebase eq 'XMLText';
	my $module = "WE_Content::" . $modulebase;
	my @args_serialize;
	my @args_new;
	if ($modulebase eq 'XML') {
	    skip "No XML::Dumper installed", $xml_tests
		unless (eval {
		    require XML::Dumper; XML::Dumper->VERSION(0.71);
		    1;
		});
	    require WE_Content::XML;
	} else {
	    skip "No XML::Parser installed", $xml_tests
		unless (eval {
		    require XML::Dumper; XML::Dumper->VERSION(0.71);
		    require XML::Parser;
		    1;
		});
	    require WE_Content::XMLText;
	    @args_serialize = (-lang => "de");
	    my $templateobject = WE_Content::Base->new(-file => "$contentdir/sample_content.bin");
	    @args_new       = (-templateobject => $templateobject->{Object},
			       -oldlang => "de");
	}
	my $xml_clone = $clone->clone($module);
	ok($xml_clone->isa($module), "a $module object");
	ok($xml_clone->isa('WE_Content::Base'));
	my $xml = $xml_clone->serialize(@args_serialize);
	like($xml, qr/^<\?xml/);
	eval { my $p = XML::Parser->new;
	       $p->parse($xml);
	   };
	is($@, "");
	my $xml_new = WE_Content::XML->new(-string => $xml);
	ok($xml_new->isa($module));
	my $xml2 = $xml_new->serialize(@args_serialize);
	ok(XML::Dumper::xml_compare($xml, $xml2), "Compare XML round-trip result");
	$xml_new = WE_Content::Base->new(-string => $xml, @args_new);
	ok($xml_new->isa('WE_Content::XML'));
	$xml2 = $xml_new->serialize(@args_serialize);
	ok(XML::Dumper::xml_compare($xml, $xml2));

    SKIP: {
	    my $tests = 4;
	    skip "utf-8 not reliable with perl 5.8.0", $tests
		if $] eq "5.008";
	    skip "No utf-8 support with this perl", $tests
		if $] < 5.006;
	    my $xml3 = $xml;
	    $xml3 =~ s/&#xE4;/\x{00e4}/g;
	    $xml3 =~ s/&#x20AC;/\x{20ac}/g;
	    eval { my $p = XML::Parser->new;
		   $p->parse($xml3);
	       };
	    is($@, "");
	    my $xml_new2 = $module->new(-string => $xml3);
	    ok($xml_new2->isa($module));
	    my $xml4;
	    eval { $xml4 = $xml_new2->serialize(@args_serialize);
	       };
	    is($@, "");
	    ok(XML::Dumper::xml_compare($xml3, $xml4), "Compare XML round-trip result with UTF-8 data");
	}

    SKIP: {
	    my $tests = 4;
	    skip "No Encode", $tests
		unless (eval { require Encode; 1 });
	    skip "utf-8 not reliable with perl 5.8.0", $tests
		if $] eq "5.008";
	    my $xml3 = $xml;
	    $xml3 =~ s/&#xE4;/\xe4/g;
	    $xml3 =~ s/encoding="utf-8"/encoding="iso-8859-1"/;
	    $xml3 = Encode::encode("iso-8859-1", $xml3);
	    eval { my $p = XML::Parser->new;
		   $p->parse($xml3);
	       };
	    is($@, "");
	    my $xml_new2 = $module->new(-string => $xml3);
	    ok($xml_new2->isa($module));
	    my $xml4;
	    eval { $xml4 = $xml_new2->serialize(@args_serialize);
	       };
	    is($@, "");
	    ok(XML::Dumper::xml_compare($xml3, $xml4), "Compare XML round-trip result with iso-8859-1 encoding");
	}
    }

}

sub cancontain_boldtext {
    my $clone = shift;
    my $cancontain_boldtext = 0;
    $clone->find(sub { my($o, %args) = @_;
		       if ($args{-key} && $args{-key} eq 'cancontain') {
			   my(%cancontain) = map { ($_ => 1) } @$o;
			   if ($cancontain{'boldtext'}) {
			       $cancontain_boldtext++;
			   }
		       }
		   });
    $cancontain_boldtext;
}

sub show_diff {
    my($s1,$s2) = @_;
    my $tmpdir = tmpdir();
    my $base   = "$tmpdir/test.$$";

    open(S1, ">$base.1") or die $!;
    print S1 $s1;
    close S1;
    open(S2, ">$base.2") or die $!;
    print S2 $s2;
    close S2;

    open(DIFF, "diff -u $base.1 $base.2 |");
    while(<DIFF>) {
	print "# $_";
    }
    close DIFF;

    unlink "$base.1";
    unlink "$base.2";
}

# REPO BEGIN
# REPO NAME tmpdir /home/e/eserte/src/repository 
# REPO MD5 c41d886135d054ba05e1b9eb0c157644
sub tmpdir {
    foreach my $d ($ENV{TMPDIR}, $ENV{TEMP},
		   "/tmp", "/var/tmp", "/usr/tmp", "/temp") {
	next if !defined $d;
	next if !-d $d || !-w $d;
	return $d;
    }
    undef;
}
# REPO END

__END__
