#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 00_we_framework.t,v 1.20 2007/10/03 10:11:25 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin qw($RealBin);
use File::Find;
use File::Basename qw(basename);

BEGIN {
    if (!eval q{
	use Test::More;
        use File::Spec::Functions qw(devnull);
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip: tests only work with installed Test::More and File::Spec modules\n";
	exit;
    }
}

# REPO BEGIN
# REPO NAME save_pwd /home/e/eserte/src/repository 
# REPO MD5 7f59b47ca12f3affcf409af03c44292e
sub _save_pwd (&) {
    my $code = shift;
    require Cwd;
    my $pwd = Cwd::cwd();
    eval {
	$code->();
    };
    my $err = $@;
    chdir $pwd or die "Can't chdir back to $pwd: $!";
    die $err if $err;
}
# REPO END

chdir "$RealBin/../lib/" or die $!;

my @mods;
find(sub {
	 return if !-f $_ || !/\.pm$/;
	 local $_ = $File::Find::name;
	 s{^\./}{};
	 s{/}{::}g;
	 s{\.pm$}{};
	 push @mods, $_;
     }, ".");

my @scripts;
_save_pwd {
    chdir "$RealBin/../scripts/" or die $!;
    find(sub {
	     $File::Find::prune = 1 if /^CVS$/;
	     return if !-f $_ || /~$/ || /^\./;
	     local $_ = $File::Find::name;
	     s{^\./}{};
	     push @scripts, $_;
	 }, ".");
};

plan tests => scalar(@mods) + scalar(@scripts);

my $tests_per_loop        = 1;
my $tests_per_script_loop = 1;
for my $mod (@mods) {
 SKIP: {
	skip "$mod is obsolete" , $tests_per_loop
	    if $mod =~ /^(WE_Frontend::Main)$/;
	skip "Data::JavaScript not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WebEditor::OldController
			 | WebEditor::OldFeatures::TeaserLink
			 )$/x && !eval { require Data::JavaScript; Data::JavaScript->VERSION(1.10) };
	skip "HyperWave modules not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WE_Sample::HW
                         | WE::DB::HWObj
		         )$/x && !eval { require HyperWave::CSP };
	skip "$mod is unfinished", $tests_per_loop
	    if $mod =~ /^(WE::Util::HWRights)$/;
	skip "SOAP module not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE::Server::SOAP' && !eval { require SOAP::Lite };
	skip "Net::NIS not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE::DB::NISUser' && !eval { require Net::NIS };
	skip "HTML::FromText not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Frontend::Plugin::HTMLFromText' && !eval { require HTML::FromText };
	skip "Apache not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( Apache::AuthenWE
                         | WebEditor::OldHandler
                         )$/x && !eval { require Apache::Constants };
	skip "DBI not available, needed for $mod", $tests_per_loop
	    if $mod eq 'Tie::DBI_DBM' && !eval { require DBI };
	skip "YAML not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WE::DB::FS
                         | WE_Content::YAML
			 | WE::DB::Info
                         )$/x && !eval { require YAML };
	skip "Tie::IxHash not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Content::IxHash' && !eval { require Tie::IxHash };
	skip "XML::Dumper not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Content::XML' && !eval { require XML::Dumper; XML::Dumper->VERSION(0.71) };
	skip "XML::Parser not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Content::XMLText' && !eval { require XML::Parser; };
	skip "XML::Writer not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Content::XMLText' && !eval { require XML::Writer; };
	skip "HTML::LinkExtor not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Frontend::LinkChecker' && !eval { require HTML::LinkExtor };
	skip "GD not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Frontend::TextImages' && !eval { require GD };
	skip "Template-Toolkit not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WE_Frontend::Plugin::
			 | WebEditor::OldFeatures::MakePS$
			 | WebEditor::OldFeatures::MakeOnePageHTML$
			 | WebEditor::OldFeatures::MakePDF$
                         | WebEditor::SystemExplorer$
			 | WebEditor::OldFeatures::HTMLFilterHack$
                         )/x && !eval { require Template };
	skip "Mail::Send not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WebEditor::OldFeatures::Notify' && !eval { require Mail::Send };
	skip "Mail::Mailer not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WebEditor::OldFeatures::Notify' && !eval { require Mail::Mailer; Mail::Mailer->VERSION(1.53) };
	skip "HTML::Entities not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WebEditor::OldFeatures::Make(PS|PDF|OnePageHTML)
                         | WebEditor::OldFeatures::XMenus
                         )$/x && !eval { require HTML::Entities };
	skip "New HTML::Entities not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WE_Frontend::Plugin::HtmlNum
                         )$/x && !eval { require HTML::Entities; HTML::Entities->VERSION(1.27) };
	skip "Archive::Tar not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WebEditor::OldFeatures::AdminExport' && !eval { require Archive::Tar };
	skip "LWP::UserAgent not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^( WE_Frontend::Publish::FTP_MD5Sync
                         | WE_Frontend::LinkChecker
                         )$/x && !eval { require LWP::UserAgent };
	skip "Time::HiRes not available, needed for $mod", $tests_per_loop
	    if $mod eq 'WE_Frontend::Plugin::Benchmark' && !eval { require Time::HiRes };
	skip "mixin::with not available, needed for $mod", $tests_per_loop
	    if $mod =~ /^WebEditor::OldFeatures::/ && !eval { require mixin::with };
	require_ok($mod);
    }
}

chdir "$RealBin/../scripts/" or die $!;
for my $script (@scripts) {
 SKIP: {
	my $base = basename $script;
	skip "XML::DOM not available", $tests_per_script_loop
	    if $base eq 'we_import_hwx' && !eval { require XML::DOM };
	skip "YAML not available", $tests_per_script_loop
	    if $base =~ /^(we_dump|we_user)$/ && !eval { require YAML };
	skip "Term::ReadKey", $tests_per_script_loop
	    if $base eq 'we_shell' && !eval { require Term::ReadKey };
	skip "HTML::Entities", $tests_per_script_loop
	    if $base eq 'we_export_content' && !eval { require HTML::Entities };

	my $cmd = "$^X -Mblib=.. -c $script > " . devnull . " 2>&1";
	#warn $cmd;
	system $cmd;
	is($?, 0, "Script $script")
	    or diag "Command line <$cmd> failed";
    }
}

__END__
