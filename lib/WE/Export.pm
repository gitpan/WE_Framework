# -*- perl -*-

#
# $Id: Export.pm,v 1.9 2005/01/10 08:28:56 eserte Exp $
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

package WE::Export;

use base qw/Class::Accessor/;

__PACKAGE__->mk_accessors(qw/Root Tmpdir Archive Verbose Force
			     _DirMode _FileMode/);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

use WE::Util::Functions qw(_save_pwd is_in_path file_name_is_absolute);

=head1 NAME

WE::Export - export a WE::DB database

=head1 SYNOPSIS

    use WE::Export;
    my $r = new WE::DB ...;
    my $ex = new WE::Export $r;
    $ex->export_all;

=head1 DESCRIPTION

This module provides export and import methods for the WE::DB database.

=cut

use File::Path;
use File::Basename;
use File::Find;
use File::Copy;
use Data::Dumper 2.101; # older versions are buggy
use DB_File;
use Fcntl;
use Safe;
use Cwd;

use vars qw(%db_filename);
%db_filename = (
    ObjDB        => 'objdb',
    UserDB       => 'userdb',
    OnlineUserDB => 'onlinedb',
    NameDB       => 'name',
);

# Should be something which is recognized by the "*" glob:
use constant MTREE_FILE => "mtree";

=head2 CONSTRUCTOR new

Called as C<new WE::Export $rootdb>. Create a new WE::Export object
for the given database C<$rootdb>. Additional arguments (as dashed
key-value pairs) will be passed to the object.

=cut

sub new {
    my($pkg, $rootdb, %args) = @_;
    my $self = { };
    bless $self, $pkg;
    $self->_DirMode(undef);
    $self->_FileMode(undef);
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	$self->{ucfirst(substr($k,1))} = $v;
    }
    $self->Root($rootdb);
    $self;
}

=head2 METHODS

=over 4

=item export_db

Create data dumper files of the metadata databases and store them into
the directory specified by the C<Tmpdir> member. Data::Dumper files
are created because most DBM file formats are incompatible between
various systems.

=cut

sub export_db {
    my $self = shift;

    my $rootdb = $self->Root;
    my $objdb = $rootdb->ObjDB;
    my $objdbfile = $objdb->DBFile;
    my $objdump;
    my $dd;

    # Note: do not use connect(), because we want the plain data, not the
    # MLDBM cooked data
    tie my %db, 'DB_File', $objdbfile, O_RDONLY, 0644
	or die "Can't tie to $objdbfile: $!";
    $dd = Data::Dumper->new([\%db],['ObjDB']);
    $dd->Indent(0);
    #$dd->Purity(1); # XXX
    $objdump = $dd->Dump;

    if (!defined $objdump) {
	die "Dump of object database is empty!";
    }

    # XXX this will not work if UserDB will switch to MLDBM!
    my $userdb = $rootdb->UserDB;
    my $userdump;
    $dd = Data::Dumper->new([$userdb->{DB}], ['UserDB']);
    $dd->Indent(0);
    #$dd->Purity(1); # XXX
    $userdump = $dd->Dump;
    if (!defined $userdump) {
	die "Dump of user database is empty!";
    }

    my $onlineuserdb = $rootdb->OnlineUserDB;
    my $onlineuserdump;
    $dd = Data::Dumper->new([$onlineuserdb->{DB}], ['OnlineUserDB']);
    $dd->Indent(0);
    #$dd->Purity(1); # XXX
    $onlineuserdump = $dd->Dump;
    if (!defined $onlineuserdump) {
	die "Dump of online user database is empty!";
    }

    my $namedb = $rootdb->NameDB;
    my $namedump;
    $dd = Data::Dumper->new([$namedb->{DB}], ['NameDB']);
    $dd->Indent(0);
    #$dd->Purity(1); # XXX
    $namedump = $dd->Dump;
    if (!defined $namedump) {
	die "Dump of name database is empty!";
    }

    my $objdboutfile  = $self->Tmpdir . "/$db_filename{ObjDB}.db.dd";
    my $userdboutfile = $self->Tmpdir . "/$db_filename{UserDB}.db.dd";
    my $onlineuserdboutfile = $self->Tmpdir . "/$db_filename{OnlineUserDB}.db.dd";
    my $namedboutfile = $self->Tmpdir . "/$db_filename{NameDB}.db.dd";

    open(DB, "> $objdboutfile") or die "Can't create $objdboutfile: $!";
    print DB $objdump;
    close DB;

    open(DB, "> $userdboutfile") or die "Can't create $userdboutfile: $!";
    print DB $userdump;
    close DB;

    open(DB, "> $onlineuserdboutfile") or die "Can't create $onlineuserdboutfile: $!";
    print DB $onlineuserdump;
    close DB;

    open(DB, "> $namedboutfile") or die "Can't create $namedboutfile: $!";
    print DB $namedump;
    close DB;

    1;
}

=item export_content

Copy the content files to the C<content> subdirectory of the directory
specified by the C<Tmpdir> member.

=cut

sub export_content {
    my $self = shift;

    my $rootdb = $self->Root;
    my $contentdb = $rootdb->ContentDB;
    my $directory = $contentdb->Directory;

    my $contentdir = $self->Tmpdir . "/content";
    mkdir $contentdir, 0755
	or die "Can't create $contentdir: $!";

    my @directories;
    my @files;

    my $wanted = sub {
	# unwanted directories
	if ($_ =~ /^(RCS|CVS|\.svn|\.AppleDouble)$/) {
	    $File::Find::prune = 1;
	    return;
	}
	# unwanted files
	if ($_ =~ /~$/) {
	    return;
	}
	if (-f $_) {
	    push @files, $File::Find::name;
	} elsif (-d $_) {
	    push @directories, $File::Find::name;
	}
    };

    _save_pwd {
	chdir $directory or die "Can't chdir to $directory: $!";
	find($wanted, ".");
	foreach my $d (@directories) {
	    mkpath(["$contentdir/$d"], $self->Verbose, 0770);
	}
	foreach my $f (@files) {
	    copy($f, "$contentdir/$f")
		or die "Can't copy file $f to $contentdir: $!";
	    copy_stat($f, "$contentdir/$f");
	}
    };

    1;
}

=item export_all

Create an archive file (.tar.gz format) of both database and content.
Two member variables control paths for the export: C<Tmpdir> specifies
the temporary directory, where database and content files will be
stored, and C<Archive> specifies the path for the generated archive
file. If not specified, then reasonable defaults are chosen (using the
systems default temp directory). After the creation of the archive
file, the temporary directory will be deleted completely.

=cut

sub export_all {
    my $self = shift;

    my @l = localtime;
    my $timestamp = sprintf "%04d%02d%02d-%02d%02d%02d",
	                    $l[5]+1900,$l[4],@l[3,2,1,0];

    if (!defined $self->Tmpdir) {
	my $tmpdir = _tmpdir() . "/we_export.$timestamp";

	if (-d $tmpdir) {
	    rmtree([$tmpdir], $self->Verbose, 1);
	}
	mkdir $tmpdir, 0775 or die "Can't create $tmpdir: $!";

	$self->Tmpdir($tmpdir);
    }

    if (!-d $self->Tmpdir || !-w $self->Tmpdir) {
	die "The directory " . $self->Tmpdir . " does not exist or is not readable";
    }

    $self->export_db;
    $self->export_content;
    $self->create_mtree;

    if (!defined $self->Archive) {
	$self->Archive(_tmpdir() . "/we_export.$timestamp.tar.gz");
    }

    _save_pwd {
	chdir $self->Tmpdir or die "Can't chdir to ".$self->Tmpdir.": $!";
	if ($^O eq 'MSWin32' && eval q{ require Archive::Tar; 1 }) {
	    my @files;
	    find(sub {
		     push @files, $File::Find::name if -f $_ && -r $_;
		 }, ".");
	    if (!@files) {
		warn "No files to archive";
	    } else {
		my $tar = Archive::Tar->new
		    or die "Can't create Archive::Tar object";
		$tar->add_files(@files);
		$tar->write($self->Archive, 9);
		if ($self->Verbose) {
		    warn "Archived to @{[ $self->Archive ]}: @files\n";
		}
	    }
	} else {
	    my $v = $self->Verbose ? "v" : "";
	    #system("tar cf${v}z ".$self->Archive." *");
	    system("tar cf${v} - * | gzip > " . $self->Archive);
	    if ($?/256 != 0) {
		warn "Error while creating ".$self->Archive.", please check.\n";
	    }
	}
    };

 CLEANUP:
    rmtree([$self->Tmpdir], $self->Verbose, 1);

    1;
}

=item import_archive($tarfile, $destdir, %args)

For the specified tar archive C<$tarfile> (previously created by
C<export_all>), the content will be extracted to the directory
C<$destdir>. The destination directory must not exist and will be
created by the method.

Further arguments %args:

=over

=item -verbose => $boolean

Be verbose.

=item -force => $boolean

Extract even if destination directory exists.

=item -only => [DB1, ...]

Extract only specified databases. Note that content is B<always> extracted.

=item -chmod => $boolean

Make chmod manipulations (set everything to 0777 resp. 0666) if set to
true.

=back

=cut

# Do not rename this to "import" :-)
sub import_archive {
    my $self = shift;
    my($tarfile, $destdir, %args) = @_;

    if (!ref $self) {
	$self = WE::Export->new(undef);
    }

    if ($args{-force}) {
	$self->Force($args{-force});
    }
    if ($args{-verbose}) {
	$self->Verbose($args{-verbose});
    }
    if ($args{"-chmod"}) {
	$self->_DirMode(0777);
	$self->_FileMode(0666);
    } else {
	$self->_DirMode(undef);
	$self->_FileMode(undef);
    }

    my $all = 1;
    my %only;
    if ($args{-only}) {
	%only = map { ($_ => 1) } @{ $args{-only} };
	$all = 0;
    }

    if (-e $destdir && !$self->Force) {
	die "Destination directory $destdir must not exist";
    }
    mkpath($destdir, $self->Verbose, $self->_DirMode);

    if (!file_name_is_absolute($tarfile)) {
	$tarfile = cwd()."/$tarfile";
    }

    _save_pwd {
	chdir $destdir or die "Can't change to $destdir: $!";
	my @filelist;
	my @dirlist;
	if ($^O eq 'MSWin32' && eval q{ require Archive::Tar; 1 }) {
	    my $tar = Archive::Tar->new($tarfile, 1)
		or die "Can't create tar object";
	    if ($self->Verbose) {
		warn "About to extract the following files from $tarfile:\n" . join(" ", $tar->list_files) . "\n";
	    }
	    $tar->extract($tar->list_files); # extract() does not work!
	} else {
	    my $v = $self->Verbose ? "v" : "";
	    #system("tar", "xf${v}pz", $tarfile);
	    system("gzip -dc < $tarfile | tar xf${v}p -");
	    if ($?/256 != 0) {
		warn "Error while extracting from $tarfile, but continuing...\n";
	    }
	    @filelist = `gzip -dc < $tarfile | tar tf -`;
	    chomp @filelist;
	    for(my $f_i = $#filelist; $f_i >= 0; $f_i--) {
		my $f = $filelist[$f_i];
		if (-d $f) {
		    push @dirlist, $f;
		    splice @filelist, $f_i, 1;
		}
	    }
	}

	my @db_files;
	for my $dbkey (qw(ObjDB UserDB OnlineUserDB NameDB)) {
	    if ($all || $only{$dbkey}) {
		$self->exportdb_to_nativedb("$db_filename{$dbkey}.db.dd", ".", $dbkey);
		push @db_files, "$db_filename{$dbkey}.db";
	    }
	}
	if (-e MTREE_FILE && is_in_path("mtree")) {
	    my $xfile = $self->_create_mtree_x_file;
	    system("mtree -X $xfile < " . MTREE_FILE);
	    unlink $xfile;
	} elsif (@filelist) {
	    if (defined $self->_FileMode) {
		warn "Changing mode of all files to " .
		    sprintf("0%o", $self->_FileMode) . "...\n";
		chmod $self->_FileMode, @filelist, @db_files;
	    }
	    if (defined $self->_DirMode) {
		warn "Changing mode of all directories to " .
		    sprintf("0%o", $self->_DirMode) . "...\n";
		chmod $self->_DirMode, @dirlist;
	    }
	} else {
	    if (defined $self->_FileMode && defined $self->_DirMode) {
		warn "No mtree and no filelist/dirlist, no chmod manipulation possible";
	    }
	}
    };

    1;
}

# $type is either ObjDB or UserDB
# This method will convert the Data::Dumper files to a DB_File.
sub exportdb_to_nativedb {
    my($self, $dbfile, $destdir, $type) = @_;

    if (!-d $destdir) {
	die "Destination directory $destdir does not exist";
    }
    if (!defined $db_filename{$type} || $db_filename{$type} eq '') {
	die "Unsupported type $type";
    }
    my $destfile = $destdir . "/" . $db_filename{$type} . ".db";

    if ($self->Force && -e $destfile) {
	unlink $destfile;
    }
    tie my %db, 'DB_File', $destfile, O_RDWR|O_CREAT, 0644
	or die "Can't tie to $destfile: $!";
    if (scalar keys %db) {
	die "Database $destfile is not empty, please remove first";
    }

    my $s = Safe->new('WE::Export::Safe');
    my $cwd = cwd;
    $s->rdo($dbfile) or die "Can't load $dbfile (in $cwd) with Safe::rdo: $!";
    my $indb;
    {
	no strict 'refs';
	$indb = $ {"WE::Export::Safe::" . $type};
    }
    if (!defined $indb || !UNIVERSAL::isa($indb, 'HASH')) {
	die "$type not defined in $dbfile";
    }
    while(my($k,$v) = each %$indb) {
	$db{$k} = $v;
    }

    untie %db;
}

# XXX This assumes that all databases and content is in the same directory
# as objdbd.db. Which may be wrong.
sub create_mtree {
    my $self = shift;
    if (!is_in_path("mtree")) {
	warn "No mtree in PATH, skipping creation of .mtree file";
	return;
    }

    my $rootdb = $self->Root;
    my $objdb = $rootdb->ObjDB;
    my $objdbfile = $objdb->DBFile;
    my $dbdir = dirname($objdbfile);

    my $xfile = $self->_create_mtree_x_file;
    my $mtree_output = `mtree -k flags,gid,mode,nlink,link,time,uid -X $xfile -c -p $dbdir`;

    my $mtree_file = $self->Tmpdir . "/" . MTREE_FILE;
    open(MTREE_FH, ">$mtree_file") or die "Can't write $mtree_file: $!";
    print MTREE_FH $mtree_output;
    close MTREE_FH;

    unlink $xfile;
}

sub _create_mtree_x_file {
    my $self = shift;
    my $xfile = _tmpdir() . "/.mtree.exclude.$$";
    open(XFILE, ">$xfile") or die "Can't write to $xfile: $!";
    print XFILE <<EOF;
.svn
CVS
RCS
*~
EOF
    close XFILE;
    $xfile;
}

# REPO BEGIN
# REPO NAME tmpdir /home/e/eserte/src/repository 
# REPO MD5 c41d886135d054ba05e1b9eb0c157644
sub _tmpdir {
    foreach my $d ($ENV{TMPDIR}, $ENV{TEMP},
		   "/tmp", "/var/tmp", "/usr/tmp", "/temp") {
	next if !defined $d;
	next if !-d $d || !-w $d;
	return $d;
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME copy_stat /home/e/eserte/src/repository 
# REPO MD5 f567def1f7ce8f3361e474b026594660

sub copy_stat {
    my($src, $dest) = @_;
    my @stat = ref $src eq 'ARRAY' ? @$src : stat($src);
    die "Can't stat $src: $!" if !@stat;

    chmod $stat[2], $dest
	or warn "Can't chmod $dest to " . sprintf("0%o", $stat[2]) . ": $!";
    chown $stat[4], $stat[5], $dest;
#  	or do {
#  	    my $save_err = $!; # otherwise it's lost in the get... calls
#  	    warn "Can't chown $dest to " .
#  		 (getpwuid($stat[4]))[0] . "/" .
#                   (getgrgid($stat[5]))[0] . ": $save_err";
#  	};
    utime $stat[8], $stat[9], $dest
	or warn "Can't utime $dest to " .
	        scalar(localtime $stat[8]) . "/" .
		scalar(localtime $stat[9]) .
		": $!";
}
# REPO END

1;

__END__

=back

=head1 BUGS

This module will only work on Windows with installed Archive::Tar and
Compress::Zlib (this is usually true with ActivePerl). On Unix, you
need the programs C<tar> and C<gzip>.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

