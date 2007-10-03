#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: Makefile.PL,v 1.59 2007/10/03 10:13:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Onlineoffice. All rights reserved.
# Copyright (C) 2002,2003,2004 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#

use vars qw(%mod_config %prereq_pm);
BEGIN {
%mod_config =
    (
     -version        => '0.40',      # required AutoInstall version
                                     # usually 0.40 is sufficient

     -config         =>
     {
      do_once => 1,
     },

     -core =>
     [
      'Class::Accessor' => 0,
      'DB_File'	  => 0,
      'DB_File::Lock'	  => 0,
      'MLDBM'		  => 0,
      # This is not exactly a WE_Framework requirement, but
      # rather a requirement of a recent File::Temp, which
      # needs is needed by Template-Toolkit, which is used
      # by WebEditor::*
      'File::Spec'      => 0.8,
      # A version which is capable of handling utf-8 data
      # For perl5.00503 there is no utf-8 support at all...
      ($] >= 5.006 ? ('Data::Dumper' => 2.121) : ()),
      mixin => 0,
     ],

     'Minimal web.editor support' =>
     [
      -default           => 0,
      'Template'         => 2.09,
      'Data::JavaScript' => 1.10, # passing data between server and client
      'HTML::Entities'   => 1.27,
      'Tie::IxHash'      => 0,    # sort order in imageeditor
      'HTML::LinkExtor'  => 0,    # link checker
      'LWP::UserAgent'   => 0,    # also link checker
      ],

     'WE_Frontend plugins' =>
     [
      -default           => 0,
      "Time::HiRes"      => 0,    # for the Benchmark plugin
      "HTML::FromText"   => 0,    # for the HTMLFromText plugin
      "Mail::Mailer"     => 1.53, # for the Notify plugin
      "Mail::Send"       => 0,    # dito
     ],

     'TextLayouter and image support' =>
     [
      -default           => 0,
      'GD'              => 1.38,
      'GD::Convert'     => 2.01,  # for gif support
     ],

     'XML export/import' =>
     [
      -default           => 0,
      'XML::Parser'      => 0,    # for WE_Content::XMLText
      'XML::Writer'      => 0,    # for WE_Content::XMLText
      'XML::Dumper'      => 0.71, # for WE_Content::XML
      'XML::LibXML'      => 0,    # for WE_Content::XML
     ],

     'YAML export/import' =>
     [
      -default           => 0,
      'YAML'             => 0.30, # also for WE::DB::FS
     ],

     'Development and documentation tools' =>
     [
      -default           => 0,
      'Test::More'       => 0, # not available on older perls
      'Devel::Cover'     => 0, # development only
      'Pod::Coverage'    => 0, # also
      'Pod::POM'         => 0, # for the documentation
      'File::NCopy'      => 0, # for content im/export test
      'Storable'         => 0, # alternative MLDBM serializer
      'Term::ReadKey'	 => 0, # for we_shell
     ],

     'Obscure features, not necessary (SOAP, Tk, HyperWave ...)' =>
     [
      -default           => 0,
      'HyperWave::CSP'  => 0,
      'SOAP::Lite'      => 0,
      'Tk'              => 800.022,
      'Tk::ObjEditor'   => 0,
      'Net::FTP'        => 0,
      ($^O ne 'MSWin32' ?
       ('Net::NIS'        => 0, # cannot be compiled with Visual C++
       ) : ()
      ),
      'VCS'              => 0.08, # for WE::DB::FS and vc
      'MIME::Types'	   => 0,
      'Algorithm::Diff' => 0,
      'Locale::Language' => 0, # only needed by HyperWave::CSP
      'Date::Parse'     => 0,
      'Digest::MD5'     => 0,
      ($^O eq 'MSWin32' ?
       ('Archive::Tar'   => 0, # on Unix, tar is used
	'Compress::Zlib' => 0,
       ) : ()
      ),
     ],
    );
}

## unused ExtUtils::AutoInstall code:
#
# # ExtUtils::AutoInstall Bootstrap Code, version 7.
# BEGIN{my$p='ExtUtils::AutoInstall';my$v=0.45;$p->VERSION||0>=$v
# or+eval"use $p $v;1"or+do{my$e=$ENV{PERL_EXTUTILS_AUTOINSTALL};
# (!defined($e)||$e!~m/--(?:default|skip|testonly)/and-t STDIN or
# eval"use ExtUtils::MakeMaker;WriteMakefile(PREREQ_PM=>{'$p',$v}
# );1"and exit)and print"==> $p $v required. Install it from CP".
# "AN? [Y/n] "and<STDIN>!~/^n/i and print"*** Installing $p\n"and
# do{if (eval '$>' and lc(`sudo -V`) =~ /version/){system('sudo',
# $^X,"-MCPANPLUS","-e","CPANPLUS::install $p");eval"use $p $v;1"
# ||system('sudo', $^X, "-MCPAN", "-e", "CPAN::install $p")}eval{
# require CPANPLUS;CPANPLUS::install$p};eval"use $p $v;1"or eval{
# require CPAN;CPAN::install$p};eval"use $p $v;1"||die"*** Please
# manually install $p $v from cpan.org first...\n"}}}
#
# use ExtUtils::AutoInstall (%mod_config);

## alternative to ExtUtils::AutoInstall
use ExtUtils::MakeMaker;
%prereq_pm = @{ $mod_config{-core} };

use Cwd;

if (0) {
    # htmlifypods was removed in EU::MM 5.50 :-(
    warn "To also create HTML pages run

    $^X Makefile.PL INST_HTMLLIBDIR=html INST_HTMLSCRIPTDIR=html

" if !grep(/INST_HTML/, @ARGV);
}

WriteMakefile
  (
   'NAME'	   => 'WE_Framework',
   'VERSION'       => '0.097_02',
   'EXE_FILES'     => [qw|
		          scripts/we_content_upgrade
		          scripts/we_create_folder_tree
		          scripts/we_create_servicepack
			  scripts/we_db_export
			  scripts/we_db_import
			  scripts/we_dump
			  scripts/we_fsck
   			  scripts/we_import_fs
   			  scripts/we_import_hwx
		          scripts/we_permission_test
			  scripts/we_user
		          scripts/we_export_content
		          scripts/we_import_content
		          scripts/we_shell
			 |
		      ],
#   'PMLIBDIRS'     => ['lib'],
   'PREREQ_PM'     => \%prereq_pm,
#
   'dist' => {'POSTOP'=>'-$(CHMOD) 664 $(DISTVNAME).tar$(SUFFIX)'},

   'ABSTRACT'      => 'The web.editor backend',
#   'ABSTRACT_FROM' => 'doc/WE_Framework_Intro.pod',
   'AUTHOR'        => 'Slaven Rezic (slaven@rezic.de)',
   'NO_META'       => 1,
  );

# ignore autoinstall.pl
sub MY::libscan {
    my($self,$path) = @_;
    return '' if MM->libscan($path) eq '';
    return '' if $path =~ m:\b(prereqinst\.pl)\b: ;
    $path;
}

sub MY::postamble {
    my $postamble = "";
    if (defined &ExtUtils::AutoInstall::postamble) {
	$postamble .= &ExtUtils::AutoInstall::postamble;
    }
    $postamble .= <<'EOF';

######################################################################
# Coverages (Code, Pod, Test not yet)

codecoverage: pure_all
	$(RM_RF) cover_db
	$(FULLPERL) -e '\
	    @f = glob("t/*.t");\
	    for (0..$$#f) {\
	        print "$$f[$$_]\n";\
	        $$args = ($$_!=$$#f ? "=-summary,0" : "");\
	        system("$$^X -MDevel::Cover$$args -Mblib $$f[$$_]");\
	    }'

podcoverage: pure_all
	$(FULLPERL) -MFile::Find -e '\
	    find(sub { return if -d;\
	               return if !/\.pm$$/;\
	               $$_=$$File::Find::name;\
	               s|^blib/lib/||; s|/|::|g; s|\.pm$$||;\
		       system "$$^X -Mblib -MPod::Coverage=$$_ -e 1";\
	             }, "blib/lib")'

######################################################################
# Module dependencies

MODDBDAT=/tmp/WE_Framework.moddb.dat
modulegraph:
	indexer.plx -o $(MODDBDAT) -b /usr/local/lib/perl5/site_perl `pwd`/lib `pwd`/scripts
	grapher.plx -o $(MODDBDAT) -s make_bundle,we_check_db,we_content_upgrade,we_create_servicepack,we_db_export,we_db_import,we_dump,we_import_fs,we_import_hwx - | xv -

######################################################################
# Additional documentation

IMGEXT=			png # or gif

HTMLDIR=		blib/html
POD2HTML_LIB=		pod2html --css=/doc/perldoc.css --htmlroot=/doc --podpath=lib:doc --netscape

documentation:	docmain \
		myhtmlifypods

docinit:
	[ -d $(HTMLDIR)/system ] && true || mkdir -p $(HTMLDIR)/system
	[ -f $(HTMLDIR)/perldoc.css ] && true || cp -p doc/perldoc.css $(HTMLDIR)

docmain:	docinit \
		$(HTMLDIR)/system/INSTALL.html \
		$(HTMLDIR)/system/internals.html \
		$(HTMLDIR)/system/sysarch.html \
		$(HTMLDIR)/system/isatree.$(IMGEXT) \
		$(HTMLDIR)/system/sysarch.$(IMGEXT) \
		$(HTMLDIR)/system/soaparch.$(IMGEXT) \
		$(HTMLDIR)/system/WE_Framework_Intro.html \
		doccleanup

doccleanup:
	rm -f doc/INSTALL.pod

$(HTMLDIR)/system/INSTALL.html:
	[ -e ../webeditor/INSTALL ] && (\
	    cp ../webeditor/INSTALL doc/INSTALL.pod; \
	    $(POD2HTML_LIB) doc/INSTALL.pod > $@ \
	) || touch $@

$(HTMLDIR)/system/WE_Framework_Intro.pod:	doc/make_WE_Framework_Intro_pod
	umask 022; doc/make_WE_Framework_Intro_pod > $@

EOF
    for my $rule (['WE_Framework_Intro.html', '$(HTMLDIR)/system/WE_Framework_Intro.pod'],
		  ['internals.html', 'doc/internals.pod'],
		  ['sysarch.html',   'doc/sysarch.pod'],
		 ) {
	my($target, @src) = @$rule;
	my $abstarget = '$(HTMLDIR)/system/' . $target;
	$postamble .= <<EOF;
$abstarget:	@src
	umask 022; \$(POD2HTML_LIB) @src > $abstarget

EOF
    }

    $postamble .= <<'EOF';
$(HTMLDIR)/system/isatree.$(IMGEXT): doc/isatree.fig
	umask 022; fig2dev -L $(IMGEXT) doc/isatree.fig $@

# should be in current directory!
$(HTMLDIR)/system/soaparch.$(IMGEXT): doc/soaparch.fig
	umask 022; cd `dirname doc/soaparch.fig` && fig2dev -L $(IMGEXT) `basename doc/soaparch.fig` ../$(HTMLDIR)/system/`basename $@`

$(HTMLDIR)/system/sysarch.$(IMGEXT): doc/sysarch.fig
	umask 022; fig2dev -L $(IMGEXT) doc/sysarch.fig $@

myhtmlifypods:
	for f in `find lib -type f -name "*.pm"`; do \
	    mkdir -p `dirname $(HTMLDIR)/$$f`; \
	    $(POD2HTML_LIB) --htmldir=$(HTMLDIR) \
			--recurse \
			--infile=$$f --outfile=$(HTMLDIR)/`dirname $$f`/`basename $$f .pm`.html; \
	done

######################################################################
# Misc

rights:
	chmod -R o+r .

# Alias
permissions: rights

EOF

    my $sf_upload = is_in_path("sf-upload");
    if (!$sf_upload) {
	$sf_upload = "$ENV{HOME}/src/sf-upload/sf-upload";
    }

    $postamble .= <<EOF;
######################################################################
# Release

release:	release-sf release-cpan

release-sf:
	$sf_upload -pr we-framework -p we-framework -f \$(DISTVNAME).tar\$(SUFFIX)

rsync-sf-doc:
	rsync -e ssh -Pvzr blib/html/ eserte\@bbbike.sourceforge.net:/home/groups/w/we/we-framework/htdocs/doc/

release-cpan:
	if [ ! -e \$(DISTVNAME).tar\$(SUFFIX) ] ; then \\
	    echo Please build \$(DISTVNAME).tar\$(SUFFIX) ; \\
	    false ; \\
	fi
	cpan-upload \$(DISTVNAME).tar\$(SUFFIX)

.PHONY: ChangeLog

ChangeLog:
	rcs2log -h users.sourceforge.net > ChangeLog

EOF

    $postamble;
}

# REPO BEGIN
# REPO NAME is_in_path /home/slavenr/work2/srezic-repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/slavenr/work2/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

__END__
