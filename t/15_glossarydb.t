#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 15_glossarydb.t,v 1.1 2002/08/12 19:36:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use WE::DB::Glossary;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 11 }

my $testdir = "$FindBin::RealBin/test";
mkdir $testdir, 0770;
ok(-d $testdir, 1);
ok(-w $testdir, 1);

my $gdbfile = "$testdir/glossary.db";
unlink $gdbfile;

my $gdb = WE::DB::Glossary->new(undef, $gdbfile);
ok(ref $gdb);
ok($gdb->isa("WE::DB::Glossary"));
my $perl_is = "The 3 virtues of every programmer: layziness, hubris, and impatience";
my $obj = $gdb->add_entry(Keyword => "perl", Description => $perl_is);
ok($obj->isa("WE::GlossaryObj"));
my $obj2 = $gdb->get_entry("perl");
ok($obj->Keyword, $obj2->Keyword);
ok($obj->Description, $obj2->Description);
ok($obj2->Description, $perl_is);
my $obj3 = WE::GlossaryObj->new;
$obj3->Keyword("java");
$obj3->Description("Bad coffee");
$gdb->add_entry($obj3);
ok($gdb->all_keywords_regex, '(\bjava\b|\bperl\b)');

$@ = "";
eval {
    $gdb->add_entry(Keyword => "perl", Description => $perl_is);
};
ok($@ ne "");

$@ = "";
eval {
    $gdb->add_entry(Keyword => "perl", Description => $perl_is, -force => 1);
};
ok($@, "");

__END__
