# -*- perl -*-

#
# $Id: Installer.pm,v 1.6 2004/06/10 13:18:02 eserte Exp $
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

package WE_Frontend::Installer;

use strict;
use vars qw($VERSION $magicfile $magiccontent);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(Main));

use CGI qw(:standard);
#use CGI::Carp qw(fatalsToBrowser);
use File::Path;
use File::Basename;
use File::stat;

use WE::Util::Functions qw(_save_pwd);

$magicfile = "magic";
$magiccontent = "Elvis is alive";

=head1 NAME

WE_Frontend::Installer - handle servicepack creation and handling

=head1 SYNOPSIS

    use WE_Frontend::Installer;
    WE_Frontend::Installer->create_servicepack($tarfile);

=head1 DESCRIPTION

This module handles servicepack creation and handling.

=head2 METHODS and FUNCTIONS

=over 4

=item new

Return a new C<WE_Frontend::Installer> object.

=cut

sub new {
    bless {}, $_[0];
}

=item objectify($self)

Return a new C<WE_Frontend::Installer> object, if it does not already
exist in C<$self>. Should be called as a static method.

=cut

sub objectify {
    my $self = shift;
    if (!$self || $self eq __PACKAGE__) {
	require WE_Frontend::MainAny;
	$self = new WE_Frontend::Installer;
	my $main = WE_Frontend::MainAny->new;
	if (!$main) {
	    die "Can't make \$main object";
	}

	$self->Main($main);
    }
    $self;
}

sub Config { shift->Main->Config(@_) }

=item main

Create a HTML page for uploading and installing a service pack. This
calls either upload_form or handle_tar.

=cut

sub main {
    my $self = shift;
    $self = objectify($self);

    print header, "<html><body bgcolor='#ffffff'>";

    eval {
	if (!param('tarfile')) {
	    $self->upload_form;
	} else {
	    $self->handle_tar;
	}
    };
    if ($@) {
	print "Folgende Fehler sind aufgetreten:",
	    br,pre(escapeHTML($@)),p;
    }

    print "<hr>";
    print '<br><a href="we_redisys.cgi?goto=siteeditorframe">';
    print "zurück zum Site-Editor</a><br></body></html>";
}

=item upload_form

Create a HTML page for uploading a service pack.

=cut

sub upload_form {
    my $self = shift;
    my $scriptname = script_name();
    print qq~
	<script>
	function check() {
	    return confirm("Das Servicepack wird im Verzeichnis @{[ $self->Config->paths->rootdir ]} installiert. Fortsetzen?");
	}
	</script>
	<form action="$scriptname" method="POST" ENCTYPE="multipart/form-data" onsubmit="return check()"><table><tr>
	<td>Servicepack-Datei: </td>
        <td><input type=file name="tarfile">
        <td><input type=submit value="upload"></td>
	</tr></table></form><br>~;
}

=item upload_form

Create a HTML page for installing a previously uploaded service pack.

=cut

sub handle_tar {
    my $self = shift;
    require Archive::Tar;
    my $uploadfile = param('tarfile');
    my $tmpdir = tmpdir();
    if (!defined $tmpdir) {
	die "Cannot find suitable temporary directory";
    }
    my $extrdir = "$tmpdir/webeditor_service";
    if (-d $extrdir) {
	rmtree([$extrdir], 0, 1);
    }
    mkdir $extrdir, 0775;
    if (!-d $extrdir) {
	die "Cannot create extraction directory $extrdir";
    }
    chdir $extrdir or die "Can't chdir to $extrdir: $!";

    my $tarfilename = "$extrdir/service.tar.gz";
    open(SP,">$tarfilename") or die "Can't writeopen $tarfilename: $!";
    binmode SP;
    while (<$uploadfile>) {
	print SP $_;
    }
    close SP;
    print "File-Upload abgeschlossen.<br>";

    my $tar = Archive::Tar->new();
    $tar->read($tarfilename);

    my $is_servicepack = 0;
    foreach my $m ($magicfile, "./$magicfile") {
	if ($tar->get_content($m) =~ /\Q$magiccontent/) {
	    $is_servicepack++;
	    last;
	}
    }

    if ($is_servicepack) {
	# XXX $tar->extract geht nicht?!
        if (!$tar->extract_archive($tarfilename)) {
	    print "Extrahieren von $tarfilename fehlgeschlagen: ". $tar->error();
	    goto CLEANUP;
	} else {
	    print "Dateien extrahiert.<br>\n";
	};
    } else {
	print "<font color=red>Das scheint kein gültiges Servicepack zu sein!</font><br>";
	goto CLEANUP;
    }

    unlink "$extrdir/$magicfile";
    $self->install($extrdir);

 CLEANUP:
    unlink $tarfilename;
}

=item install($dir)

Install the contents of directory C<$dir> to the rootdir of the
system.

=cut

sub install {
    my($self, $dir) = @_;

    if (-e "$dir/install.pl") {
	if (-x "$dir/install.pl") {
	    system("$dir/install.pl");
	    if ($?/256!=0) {
		print "Fehler beim Ausführen von install.pl!<br>\n";
	    }
	} else {
	    print "install.pl ist nicht ausführbar.<br>\n";
	}
    } else {
	print "Kopieren:\n<br>";
	my(@f) = glob("$dir/*");
	@f = grep { $_ !~ /\.tar\.gz$/ } @f; # tar.gz-Dateien ausschließen
	my @cmd = ('cp', '-Rf', @f, $self->Config->paths->rootdir);
	print join(" ",@cmd), "<br>";
	system(@cmd);
    }

 CLEANUP: 1;
    # XXX missing cleanup of $dir
}

sub tmpdir {
    foreach my $d ("/tmp", "/var/tmp", "/usr/tmp", "/temp", "C:/temp", "C:/windows/temp", "D:/temp") {
	next if !defined $d;
	next if !-d $d || !-w $d;
	return $d;
    }
    undef;
}

=item WE_Frontend::Installer->create_servicepack($destfile, %args)

=item $self->create_servicepack($destfile, %args)

Create a service pack file. Ignores all WEsiteinfo*.pm files.

The %args hash may contain the following key-value pairs:

=over 4

=item -wesiteinfo

If -wesiteinfo is specified, then use this file as the WEsiteinfo.pm
file for the target site. Most times there is a WEsiteinfo.pm file for
local development and a WEsiteinfo_customer.pm file for the customer
site.

=item -since date

Only include files newer than C<date>. L<Date::Parse> is used for
parsing the date string.

=item -v

Set to 1 to generate verbose messages.

=back

=cut

sub create_servicepack {
    my($self, $destfile, %args) = @_;

    $self = objectify($self);

    if (!defined $destfile) {
	die "Destfile not given";
    }

    my $since;
    if (defined $args{-since}) {
	require Date::Parse;
	$since = Date::Parse::str2time($args{-since});
	if (!defined $since) {
	    die "Could not parse the date $args{-since}";
	}
    }
    my $v = $args{-verbose};

    require Archive::Tar;
    require File::Find;

    require 5.006; # this perl includes a version of File::Find which can
                   # follow symlinks

    my $tar = new Archive::Tar;

    my $is_new = sub {
	my $file = shift;
	return (!defined $since || stat($file)->mtime > $since);
    };

    my @files;
    my $wanted = sub {
	if (-d $_ && (/^(RCS|CVS|\.svn|headlines|photos)$/ ||
		      $File::Find::name =~ m;(we_data/content|html/.+);)) {
	    $File::Find::prune = 1;
	    return;
	}
	if (-f $_ && (/^(\.cvsignore|WEsiteinfo.*\.pm|.*~|\.\#.*)$/ ||
		      $File::Find::name =~ m;( we_data/.*\.db$ |
					       we_data/.*\.lock$
					     );x)
		     ) {
	    return;
	}
	if (-f $_) {
	    return if !$is_new->($_);
	    push @files, $File::Find::name;
	}
    };

    my $rootdir = $self->Config->paths->rootdir;
    my $cgidir = $self->Config->paths->cgidir;
    _save_pwd {
	chdir $rootdir or die "Can't chdir to $rootdir: $!";

	File::Find::find({wanted => $wanted, follow => 1 }, ".");

	# Hmmm... add_files does not work?!
	# But nevertheless I need resolved symbolic links, so this is the
	# only possibility.
	foreach my $f (@files) {
	    warn "Add $f ...\n" if $v;
	    _tar_add_file($tar, $f);
	}
    };

    if ($args{-wesiteinfo}) {
	my $as = $cgidir;
	$as =~ s|^$rootdir/*||;
	$as .= "/WEsiteinfo.pm";
	if ($is_new->($args{-wesiteinfo})) {
	    warn "Add $as ...\n" if $v;
	    _tar_add_file($tar, $args{-wesiteinfo}, $as);
	}
    }

    $tar->add_data($magicfile, $magiccontent);

    $tar->write($destfile, 9)
	or die "Can't write to $destfile: " . $tar->error;

}

sub _tar_add_file {
    my($tar, $f, $as) = @_;
    open(F, $f) or die "Can't open file $f: $!";
    local $/ = undef;
    my $buf = <F>;
    close F;
    $as = $f if !defined $as;
    my $s = stat $f;
    my %stat = (mode => $s->mode,
		mtime => $s->mtime);
    $tar->add_data($as, $buf, \%stat);
}

1;

__END__

=back

=head1 AUTHOR

Olaf Maetner - maetzner@onlineoffice.de
Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

