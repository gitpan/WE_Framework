package WebEditor::OldFeatures::AdminExport;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use CGI qw(param);
use Archive::Tar;

sub do_export {
    my $self = shift;
    my $c = $self->C;

    my $tarfilename = "backup_".get_date().".tgz";
    my $tarfile = $c->paths->cgidir."/backup/".$tarfilename;
    my @files;
    my $file;

    opendir DIR, $c->paths->database
	or die "Can't open directory " . $c->paths->database . ": $!";
    while (defined($file = readdir(DIR))) {
	next if $file =~ /^\.|CVS/i; # ignore hidden files
	push @files, $file if not -d $c->paths->database."/".$file;
    }
    closedir DIR;

    opendir DIR, $c->paths->database."/content"
	or die "Can't open directory " . $c->paths->database . "/content: $!";
    while (defined($file = readdir(DIR))) {
	next if $file =~ /^\.|CVS/i; # ignore hidden files
	push @files, "content/".$file if not -d $c->paths->database."/content/".$file;
    }
    closedir DIR;

    my $tar = Archive::Tar->new();
    chdir $c->paths->database or die "Can't chdir: $!";
    my $ok = $tar->add_files(@files);
    $ok = $ok && $tar->add_data(".theanswer","42");
    if (!$tar->write($tarfile,9) || !$ok) {
	print "kann Archivdatei nicht erzeugen: ".$tar->error;
    } else {
	print "Archivdatei \"$tarfilename\" erzeugt.<br>\n";
	#XXX kann man überhaupt auf dieses Verzeichnis zugreifen???
	print "Bitte <a href='" . $c->paths->cgiurl . "/backup/$tarfilename'>hier</a> herunterladen und gut aufbewahren.<br>\n";
    }
    chdir $c->paths->cgidir;
}

sub do_import {
    my $self = shift;
    my $c = $self->C;

    if (!param('tarfile')) {
	print qq~
  		<form action="@{[ $c->paths->cgiurl ]}/we_redisys.cgi" method="POST" ENCTYPE="multipart/form-data"><table><tr>
  		<td>Backup-Datei: </td>
                  <td><input type=file name="tarfile">
  		<input type=hidden name="goto" value="admin">
  		<input type=hidden name="action" value="import">
                  <td><input type=submit value="upload"></td>
  		</tr></table></form><br>~;
    } else {
	require Archive::Tar;
	my $uploadfile = param('tarfile');
	my $tarfile = $c->paths->cgidir."/backup/upload.tgz";
	open(BACKUP,">$tarfile") or die "Can't write to $tarfile: $!";
	binmode BACKUP;
	while (<$uploadfile>) {
	    print BACKUP $_;
	}
	close BACKUP;
	print "File-upload abgeschlossen. $tarfile<br>";
	my $tar = Archive::Tar->new();
	$tar->read($tarfile);
	if ($tar->get_content(".theanswer") =~ "42") {
	    $tar->remove(".theanswer");
	    chdir $c->paths->database
		or die "Can't chdir to " . $c->paths->database . ": $!";
	    if (!$tar->extract_archive($tarfile)) {
		print "geht nich: " . $tar->error();
	    } else {
		print "Datenfiles extrahiert.<br>";
	    };
	} else {
	    print "<font color=red>Dies scheint keine gültige Backup-datei zu sein!</font><br>\n";
	    print "Es wurden keine Dateien extrahiert.<br>\n";
	}
	chdir $c->paths->cgidir;
    }
}

####################################################################
#
# general subs
#
sub get_date {
    # Return time as ISO 8601 date from given time in days
    my $time = time;
    my @l = localtime $time;
    sprintf("%04d-%02d-%02d-%02d%02d",
            $l[5]+1900, $l[4]+1, $l[3],
            $l[2],      $l[1],   $l[0]);
}

1;
