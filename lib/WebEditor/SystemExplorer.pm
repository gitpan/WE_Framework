# -*- perl -*-

#
# $Id: SystemExplorer.pm,v 1.6 2004/10/08 15:20:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::SystemExplorer;

use strict;
no strict 'refs';
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use File::Spec;
use File::Basename qw(dirname basename);
use File::Path qw(mkpath);
use File::Copy qw(cp);

use Template;

use constant UPLOADDIR => "/tmp/templateeditorupload";

use constant DEBUG => 0;

sub OK {
    if (defined &Apache::Constants::OK) {
	Apache::Constants::OK();
    } else {
	1;
    }
}

sub http_header {
    my($self, $type) = @_;
    my $r = $self->{R};
    if ($r) {
	$r->send_http_header($type);
    } elsif (!$self->{Controller}{HeaderPrinted}) {
	my $cgi = $self->{CGI};
	$type = "text/html" if !defined $type;
	print $cgi->header($type);
	$self->{Controller}{HeaderPrinted}++;
    }
}

sub new {
    my($class, $oc) = @_;
    my $self = { Controller => $oc,
		 R          => $oc->R,
		 C          => { WEsiteinfo => $oc->C },
	       };
    my $cgi;
    if ($ENV{MOD_PERL} && eval q{ require Apache::Request; 1 }) {
	$cgi = Apache::Request->new($self->{R});
    } else {
	require CGI;
	$cgi = CGI->new;
    }
    $self->{CGI} = $cgi;

    bless $self, $class;
}

sub dispatch {
    my $self = shift;

    my($cgi, $c) = @{$self}{qw(CGI C)};
    my $wesiteinfo = $c->{WEsiteinfo};

    my $t = Template->new
	(#DEBUG => $debug, # XXX make templates debug-clean
	 INCLUDE_PATH => [$wesiteinfo->paths->site_we_templatebase,
			  $wesiteinfo->paths->we_templatebase],
	 PLUGIN_BASE => ["WE_" . $wesiteinfo->project->name . "::Plugin",
			 "WE_Frontend::Plugin"],
	);

    $self->{TT}    = $t;

    my $action = $cgi->param("action") || "";
    my $path   = $cgi->param("path") || "";
    if      ($action eq 'newfileform') {
	return $self->new_file_form($path);
    } elsif ($action eq 'newfile') {
	return $self->new_file($path);
    } elsif ($action eq 'delfile') {
	return $self->do_del_file($path);
    } elsif ($action eq 'newdirform') {
	return $self->new_dir_form($path);
    } elsif ($action eq 'newdir') {
	return $self->new_dir($path);
    } elsif ($action eq 'download') {
	return $self->do_download($path);
    } elsif ($action eq 'upload') {
	return $self->upload_intermediate_page($path);
    } elsif ($action eq 'doupload') {
	return $self->do_upload($path);
    } elsif ($action eq 'version') {
	return $self->version_page($path);
    } else {
	# just show it
	return $self->directory_or_file($path);
    }
}

sub directory_or_file {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)};
    my $wesiteinfo = $c->{WEsiteinfo};
    $path = "/" if !defined $path || $path eq '';
## ja?
#      my $msg;
#      if (!$self->check_permissions($path, \$msg)) {
#  	die $msg;
#      }
    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);
    if (-d $abspath) {
	$self->directory_listing($path, %args);
    } elsif (-f $abspath) {
	$self->file_page($path, %args);
    } else {
	die "Invalid file type: $abspath";
    }
}

sub directory_listing {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);
    my @file;
    if (opendir(D, $abspath)) {
	my $f;
	while(defined($f = readdir(D))) {
	    next if $f =~ /(^(RCS$|CVS$|\.)|~$ )/x;
	    my $desc = "";
	    if (open(DESC, File::Spec->catfile($abspath, ".desc.$f"))) {
		local $/ = undef;
		$desc = <DESC>;
		close DESC;
	    }
	    my $absfile = File::Spec->catfile($abspath,$f);
	    my @s = stat $absfile;
	    push @file, {path      => File::Spec->catfile($path,$f),
			 directory => -d $absfile,
			 symlink   => -l $absfile,
			 symlink_target => (-l $absfile ? readlink($absfile) : undef),
			 name      => $f,
			 stat	   => \@s,
			 modtime   => $s[9],
			 size	   => $s[7],
			 desc      => $desc,
			 (DEBUG ? (fs_path   => File::Spec->catfile($abspath,$f)) : ()),
			};
	}
	closedir D;
    }
    @file = sort { $a->{name} cmp $b->{name} } @file;

    if ($path ne '/') {
	unshift @file, {path      => dirname($path),
			directory => 1,
			name      => "Parent directory",
			desc      => "Zur nächsthöheren Ebene (" . dirname($path) . ") wechseln",
			s	  => [],
			size      => "",
			modtime   => "",
			(DEBUG ? (fs_path   => dirname($abspath)) : ()),
		       };
    }

    $self->http_header("text/html");

    $t->process("tmpleditor_dirlisting.tpl.html",
		{ message => $message,
		  htmlmessage => $htmlmessage,
		  paths => $wesiteinfo->paths,
		  files => \@file,
		  r => $r,
		  currentdir => $path,
		  currentdirfs => $abspath,
		  dirwritable => -w $abspath,
		  debug => DEBUG,
		}) or die $t->error;

    OK;
}

sub file_page {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);

    my $imgurl;
    my $text;
    my $text_fragment;
    if ($path =~ /\.(gif|jpe?g|png|tiff?)$/) {
	$imgurl = File::Spec->catfile($wesiteinfo->paths->rooturl, $path);
    } elsif (-T $abspath && open(my $f, $abspath)) {
	local $/ = undef;
	$text = <$f>;
	if (length($text) > 1024) {
	    $text_fragment = substr($text, 0, 512) . "\n\n    ... (Teile der Datei weggelassen, bitte Download für Ansicht der kompletten Datei benutzen) ...\n\n" . substr($text, -512);
	}
    }

#      my @versions;
#      my $vcs_url = "vcs://localhost/VCS::" . VCS_IMPL . $abspath;
#      eval {
#  	my $vcs = VCS::File->new($vcs_url);
#  	@versions = $vcs->versions;
#      };
#      if ($@) {
#  	warn $@;
#      }

    $self->http_header("text/html");

    $t->process("tmpleditor_filepage.tpl.html",
		{ message => $message,
		  htmlmessage => $htmlmessage,
		  paths => $wesiteinfo->paths,
		  r => $r,
		  currentfile => $path,
		  currentbasename => basename($path),
		  parentdir => dirname($path),
		  imgurl => (defined $imgurl ? $imgurl : undef),
		  text => $text,
		  textfragment => $text_fragment,
#		  versions => \@versions,
		  filewritable => -w $abspath,
		  selfuri => $r ? $r->uri : $cgi->url(-relative => 1),
		}) or die $t->error;

    OK;
}

#  sub version_page {
#      my($self, $path, %args) = @_;
#      my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
#      my $message = $args{-message};
#      my $htmlmessage = $args{-htmlmessage};

#      my $rootdir = $wesiteinfo->paths->rootdir;
#      my $abspath = File::Spec->catfile($rootdir, $path);

#      my $version_nr = $cgi->param("version");

#      my $vcs_url = "vcs://localhost/VCS::" . VCS_IMPL . $abspath . "/$version_nr";
#      my $vcs = VCS::File->new($vcs_url);

#      my $imgurl;# XXX not implemented
#      my $text;
#      my $text_fragment;
#      if (-T $abspath && open(my $f, $abspath)) {
#  	local $/ = undef;
#  	$text = <$f>;
#  	if (length($text) > 2048) {
#  	    $text_fragment = substr($text, 0, 1024) . "\n\n    ... (Teile der Datei weggelassen, bitte Download für komplette Datei benutzen) ...\n\n" . substr($text, -1024);
#  	}
#      }

#      $t->process("tmpleditor_versionpage.tpl.html",
#  		{ message => $message,
#  		  htmlmessage => $htmlmessage,
#  		  paths => $wesiteinfo->paths,
#  		  r => $r,
#  		  currentfile => $path,
#  		  version => $version_nr,
#  		  imgurl => $imgurl,
#  		  text => $text,
#  		  textfragment => $text_fragment,
#  		  versions => \@versions,
#  		}) or die $t->error;

#      return Apache::Constants::OK();
#  }

#sub upload_intermediate_page {
sub do_upload {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};
    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);

    if ($cgi->param("uploadfile") eq '') {
	return $self->file_page($path, -message => "Bitte Uploaddatei angeben.");
    }

    mkpath([UPLOADDIR],0,0775);

#      tie my %sess, 'Apache::Session::DB_File', undef,
#  	{ FileName => UPLOADDIR . "/sessions.db", # XXX make configurable
#  	  LockDirectory => '/tmp',
#  	}
#  	    or die "Can't tie Apache::Session: $!";
#      my $sessionid = $sess{_session_id};
#    my $dest_file = File::Spec->catfile(UPLOADDIR, "upload-$sessionid");
    my $dest_file = UPLOADDIR . "/$$";

    my $upload = $cgi->upload("uploadfile");
    if (!$upload) {
	return $self->file_page($path, -message => "Kein Upload?");
    }

    open(my $out_fh, "> $dest_file") or die "Can't write to $dest_file: $!";
    my $in_fh = ref $upload && $upload->can("fh") ? $upload->fh : $upload;
    while(<$in_fh>) {
	print $out_fh $_;
    }
    close $in_fh;
    close $out_fh or do {
	return $self->file_page($path, -message => "Schreiben der Datei <$dest_file> fehlgeschlagen: $!");
    };

    if (!cp($dest_file, $abspath)) {
	unlink $dest_file;
	return $self->file_page($path, -message => "Kopieren von <$dest_file> nach <$abspath> fehlgeschlagen: $!");
    }
    unlink $dest_file;

    my $msg = "";
    eval {
	upload_hook($path, $abspath, \$msg);
    };
    if ($@ && $@ !~ /Undefined subroutine &WebEditor::SystemExplorer::upload_hook called/) {
	return $self->file_page($path, -message => "Der Upload-Hook für $path hat die folgende Fehlermeldung erzeugt: $@");
    }

    $self->file_page($path, -message => "Der Upload war erfolgreich. $msg");
}

#  sub do_upload {
#      my($self, $path, %args) = @_;
#      my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
#      my $message = $args{-message};
#      my $htmlmessage = $args{-htmlmessage};
#      my $rootdir = $wesiteinfo->paths->rootdir;
#      my $abspath = File::Spec->catfile($rootdir, $path);

#      tie my %sess, 'Apache::Session::DB_File', $cgi->param("sessionid"),
#  	{ FileName => UPLOADDIR . "/sessions.db", # XXX make configurable
#  	  LockDirectory => '/tmp',
#  	}
#  	    or die "Can't tie Apache::Session with id " . $cgi->param("sessionid") . ": $!";

#      my $uploadfile = $sess{file};
#      if (!-e $uploadfile) {
#  	return $self->file_page($path, -message => "Upload fehlgeschlagen. Datei auf dem Server <$uploadfile> existiert nicht mehr.");
#      }

#      my $logentry = $cgi->param("logentry")||"";

#      my $vcs_url = "vcs://localhost/VCS::" . VCS_IMPL . $abspath;
#      my $vcs;
#      eval {
#  	$vcs = VCS::File->new($vcs_url);
#      };
#      if (!$vcs) {
#  	my $rcsdir = File::Spec->catfile(dirname($abspath), "RCS");
#  	if (!-d $rcsdir) {
#  	    mkdir $rcsdir;
#  	}
#  	if (!-d $rcsdir) {
#  	    return $self->file_page($path, -message => "Das RCS-Verzeichnis <$rcsdir> konnte nicht angelegt werden.");
#  	}
#  	eval {
#  	    $vcs = VCS::File->new($vcs_url);
#  	};
#  	if (!$vcs) {
#  	    # erst einmal alte Version erzeugen
#  	    system("ci", "-l", $abspath);
#  	}
#      }

#      if (!cp($uploadfile, $abspath)) {
#  	return $self->file_page($path, -message => "<$uploadfile> konnte nicht nach <$abspath> kopiert werden.");
#      }

#      system("ci", "-m$logentry", "-l", $abspath);

#      $vcs = VCS::File->new($vcs_url);

#      my $version_nr = ($vcs->versions)[-1]->version;

#      tied(%sess)->delete;

#      $self->file_page($path, -message => "Version $version_nr erfolgreich angelegt.");

#  }

sub do_download {
    my($self, $path) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);

    my $contenttype = "application/octet-stream";
    $self->http_header($contenttype);
    open(my $fh, $abspath) or die "Can't open $abspath: $!";
    while(<$fh>) {
	print $_;
    }
    OK;
}

sub do_del_file {
    my($self, $path) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)};
    my $wesiteinfo = $c->{WEsiteinfo};
    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);
    unlink $abspath;
    if (-e $abspath) {
	return $self->file_page($path, -message => "Die Datei <$path> konnte nicht gelöscht werden. Grund: $!");
    }
    $self->directory_listing(dirname($path), -message => "Die Datei <$path> wurde erfolgreich gelöscht.");
}

sub new_file_form {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    $self->http_header("text/html");

    $t->process("tmpleditor_newfile.tpl.html",
		{ message => $message,
		  htmlmessage => $htmlmessage,
		  paths => $wesiteinfo->paths,
		  r => $r,
		  currentdir => $path,
		}) or die $t->error;

    OK;
}

sub new_file {
    my($self, $path, %args) = @_;

    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    if ($cgi->param("uploadfile") eq '') {
	return $self->new_file_form($path, -message => "Bitte Uploaddatei angeben.");
    }

    my $basename = $cgi->param("filename") || "";
    if ($basename ne "" && _invalid_file_name($basename)) {
	return $self->new_file_form($path, -message => "Dateiname ist ungültig");
    }

    my $upload = $cgi->upload("uploadfile");
    if (!$upload) {
	return $self->new_file_form($path, -message => "Kein Upload?");
    }

    if ($basename eq '') {
	$basename = basename($upload->filename);
	$basename =~ s|.*\\||; # strip DOS file names
	if (_invalid_file_name($basename)) {
	    return $self->new_file_form($path, -message => "Automatisch ermittelter Dateiname <$basename> ist ungültig, bitte einen anderen Dateinamen angeben.");
	}
    }

    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);

    my $out_name = File::Spec->catfile($abspath, $basename);

    open(my $out_fh, "> $out_name") or die "Can't write to $out_name: $!";
    my $in_fh = ref $upload && $upload->can("fh") ? $upload->fh : $upload;
    while(<$in_fh>) {
	print $out_fh $_;
    }
    close $in_fh;
    close $out_fh;

    my $msg = "";
    eval {
	newfile_hook($path, $abspath, \$msg);
    };
    if ($@ && $@ !~ /Undefined subroutine &WebEditor::SystemExplorer::newfile_hook called/) {
	return $self->file_page($path, -message => "Der Hook für $path hat die folgende Fehlermeldung erzeugt: $@");
    }

    return $self->directory_listing($path, -message => "Die Datei <$basename> wurde erfolgreich gespeichert. $msg");
}

sub new_dir_form {
    my($self, $path, %args) = @_;
    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    $self->http_header("text/html");

    $t->process("tmpleditor_newdir.tpl.html",
		{ message => $message,
		  htmlmessage => $htmlmessage,
		  paths => $wesiteinfo->paths,
		  r => $r,
		  currentdir => $path,
		}) or die $t->error;

    OK;
}

sub new_dir {
    my($self, $path, %args) = @_;

    my($r, $cgi, $t, $c) = @{$self}{qw(R CGI TT C)}; my $wesiteinfo = $c->{WEsiteinfo};
    my $message = $args{-message};
    my $htmlmessage = $args{-htmlmessage};

    my $basename = $cgi->param("dirname") || "";
    if ($basename eq "") {
	return $self->new_dir_form($path, -message => "Es wurde kein Verzeichnisname angegeben.");
    }
    if (_invalid_file_name($basename)) {
	return $self->new_dir_form($path, -message => "Verzeichnisname ist ungültig");
    }

    my $rootdir = $wesiteinfo->paths->rootdir;
    my $abspath = File::Spec->catfile($rootdir, $path);

    my $out_name = File::Spec->catfile($abspath, $basename);

    mkdir $out_name, 0777;
    if (!-d $out_name) {
	return $self->new_dir_form($path, -message => "Das Verzeichnis $out_name konnte nicht erzeugt werden: $!");
    }

    return $self->directory_listing($path, -message => "Das Verzeichnis <$basename> wurde erfolgreich erzeugt.");
}

sub check_permissions {
    my($self, $relpath, $msgref) = @_;
    if (_invalid_path_name($relpath)) {
	$$msgref = "Invalid file name (contains ..): $relpath"
	    if ref $msgref;
	return 0;
    }
    if ($relpath !~ m#^(|images|styles|we/(styles|script|images|we_templates|oszportal_(templates|prototypes|we_prototypes)))/#) {
	$$msgref = "Invalid file name: $relpath"
	    if ref $msgref;
	return 0;
    }
    return 1;
}

sub _invalid_path_name {
    my $file = shift;
    return 1 if $file =~ /(^|\/)\.\.($|\/)/;
}

sub _invalid_file_name {
    my $file = shift;
    return 1 if $file =~ m|/|;
    return 1 if $file =~ m|^\.|; # no hidden files, please
    return _invalid_path_name($file);
}

1;

__END__
