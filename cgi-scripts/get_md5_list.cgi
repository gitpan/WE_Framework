#!/usr/bin/perl
# -*- perl -*-

#
# $Id: get_md5_list.cgi,v 1.3 2003/01/16 14:29:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

BEGIN {
    # Netscape and Roxen servers do not like warnings...
    if (defined $ENV{SERVER_SOFTWARE} &&
	$ENV{SERVER_SOFTWARE} =~ /(netscape|roxen)/i) {
	$SIG{__WARN__} = sub { };
    } else {
	#$^W = 1;
	$^W = 0;
    }
    $| = 1;
}

use CGI qw(:standard);
use File::Find;
use strict;
use vars qw(@directories @digest_method @exclude %exclude $verbose);

# CONFIG ###########################################################
# Please change config variables in $0.config!
# See documentation in WE_Frontend::Publish::FTP_MD5Sync

# a list directories to get md5 hashes
@directories = ($ENV{DOCUMENT_ROOT} || do { require Cwd; Cwd::cwd() });

# the digest method to be used
@digest_method = ('perl:Digest::MD5',
		  'perl:MD5',
		  'cmd:md5',
		  'cmd:md5sum',
		  'perl:Digest::Perl::MD5',
		  'cmd:cksum',
		  'stat:modtime',
		 );

# A list of exclude regular expressions. Global exclusion against full path.
@exclude = ();
# Per directory list of excude regular expressions. Match against
# partial path.
%exclude = ();

# verbose? Do not use this for servers writing stderr to stdout!
$verbose = 0;

####################################################################

eval q{local $SIG{'__DIE__'};
       do "$0.config";
      };
#die "No config file $0.config found: $@" if $@;
warn $@ if $@ and $^W;

if ($verbose) {
    $^W = 1;
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

my %files;
my %md5;
my @curr_exclude;

sub _exclude {
    my($name, $dir) = shift;
    warn "Check $name for exclusion\n" if $^W;
    foreach my $exc (@curr_exclude) {
	if ($name =~ /$exc/) {
	    warn "Exclude $name because of $exc\n" if $^W;
	    return 1;
	}
    }
    0;
}

sub wanted {
    my $dir = shift;
    if (-f $_) {
	return if _exclude($File::Find::name, $dir);
	(my $stripped = $File::Find::name) =~ s|^./||;
	push @{ $files{$dir} }, $stripped;
    }
}

foreach my $dir (@directories) {
    _save_pwd {
	chdir $dir or die "Can't chdir to $dir: $!";
	@curr_exclude = @exclude;
	push @curr_exclude, @{$exclude{$dir}} if ref $exclude{$dir} eq 'ARRAY';
	find(sub { wanted($dir, @_) }, ".");
    };
}

my $digest_method;
my $digest_context; # XXX not used (yet)
foreach my $try_digest_method (@digest_method) {
    no strict 'refs';
    (my $escaped = $try_digest_method) =~ s/:/_/g;
    my $sub = "can_$escaped";
    if (defined &$sub) {
	$digest_context = &$sub;
	if ($digest_context) {
	    $digest_method = "do_$escaped";
	    last;
	}
    }
}
if (!defined $digest_method) {
    die "No digest method found, tried: @digest_method";
}

warn "Using method $digest_method\n" if $^W;

while(my($dir, $filesref) = each %files) {
    foreach my $file (@$filesref) {
	no strict 'refs';
	push @{ $md5{$dir} }, [$file => &$digest_method("$dir/$file")];
    }
}

my $list = list();

my $encoding;
my $accept_encoding = http('HTTP_ACCEPT_ENCODING');
if ($accept_encoding) {
    my %encoding;
    foreach (split(/\s*,\s*/, $accept_encoding)) {
        $encoding{$_} = 1;
    }
 TRY: {
        if ($encoding{'gzip'} || $encoding{'x-gzip'}) {
	    if (eval 'require Compress::Zlib; 1') {
		$list = Compress::Zlib::memGzip($list);
		$encoding = "gzip";
		last TRY;
	    } elsif (is_in_path("gzip") && eval 'require IPC::Open2; 1') {
		my $pid = IPC::Open2::open2(\*RDR, \*WTR, "gzip");
		if (!defined $pid) {
		    die "Cannot open2 with gzip";
		}
		print WTR $list;
		close WTR;
		local $/ = undef;
		$list = <RDR>;
		$encoding = "gzip";
		last TRY;
            }
        }
    }
}

print header(-type => "text/plain",
	     ($encoding ? ("Content-encoding" => $encoding) : ()),
	    ),
      $list;

######################################################################
sub can_perl_Digest__MD5 {
    eval 'require Digest::MD5; 1';
}

sub can_perl_MD5 {
    eval 'require MD5; 1';
}

sub can_perl_Digest__Perl__MD5 {
    eval 'require Digest::Perl::MD5; 1';
}

sub can_cmd_md5sum {
    is_in_path("md5sum");
}

sub can_cmd_md5 {
    is_in_path("md5");
}

sub can_cmd_cksum { 0 }

sub can_stat_modtime { 1 }

######################################################################
sub do_perl_any_md5 {
    my($module, $file) = @_;
    my $md5 = $module->new;
    open(F, $file) or die "Can't open file $file: $!";
    $md5->addfile(\*F);
    close F;
    $md5->hexdigest;
}

sub do_perl_Digest__MD5 {
    my($file) = @_;
    do_perl_any_md5("Digest::MD5", $file);
}

sub do_perl_MD5 {
    my($file) = @_;
    do_perl_any_md5("MD5", $file);
}

sub do_perl_Digest__Perl__MD5 {
    my($file) = @_;
    do_perl_any_md5("Digest::Perl::MD5", $file);
}

sub do_cmd_md5sum {
    my($file) = @_;
    my $cmd = "md5sum " . qs($file);
    chomp(my($res) = `$cmd`);
    if ($?/256 != 0 || $res =~ /^\s*$/) {
	die "Cannot run md5sum on $file";
    }
    (split /\s+/, $res)[0];
}

sub do_cmd_md5 {
    my($file) = @_;
    my $cmd = "md5 -q " . qs($file);
    chomp(my($res) = `$cmd`);
    if ($?/256 != 0 || $res =~ /^\s*$/) {
	die "Cannot run md5 on $file";
    }
    $res;
}

sub do_cmd_cksum {
    die "NYI";
}

sub do_stat_modtime {
    my($file) = @_;
    my(@stat) = stat($file);
    die "Cannot stat $file: $!" if !@stat;
    $stat[9];
}

######################################################################
sub list_header {
    my $header = "";
    if ($digest_method =~ /md5/i) {
	$header .= "# digest: MD5\n";
    } elsif ($digest_method =~ /stat_modtime/i) {
	$header .= "# digest: modtime\n";
    } elsif ($digest_method =~ /cksum/i) {
	$header .= "# digest: cksum\n";
    } else {
	die "Unhandled digest method $digest_method";
    }
    $header .= "# method: $digest_method\n";
    $header;
}

sub list_entry {
    my($entry) = @_;
    if ($entry->[0] =~ /\t/) {
	die "Fatal error: filename should not have a tab character";
    }
    "$entry->[0]\t$entry->[1]\n";
}

sub list {
    my $s = list_header();
    while(my($dir,$filesref) = each %md5) {
	$s .= "# directory: $dir\n";
	foreach my $entry (@$filesref) {
	    $s .= list_entry($entry);
	}
    }
    $s;
}

######################################################################

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0
sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

# REPO BEGIN
# REPO NAME qs /home/e/eserte/src/repository 
# REPO MD5 a6bf14672c63041f27d653eeb60c995e
sub qs {
    join(" ", map {
	my $s = $_;
	$s =~ s/\'/\'\"\'\"\'/g;
	"'${s}'";
    } @_);
}
# REPO END

__END__
