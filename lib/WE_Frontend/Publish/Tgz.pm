# -*- perl -*-

#
# $Id: Tgz.pm,v 1.5 2004/12/23 17:36:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Publish::Tgz;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use WE_Frontend::Publish;
use WE::Util::Functions qw(_save_pwd);

use File::Basename;

# for compatibility:
sub WE_Frontend::Main::publish_tgz {
    my($self, %args) = @_;
    publish_tgz($self, %args);
}

# Return created $archivefile
sub publish_tgz {
    my($self, %args) = @_;

    require Archive::Tar;
    require File::Find;
    require File::Spec;

    my $v = $args{-v};

    my $archivefileformat = $self->Config->staging->archivefile;
    my $pubhtmldir = $self->Config->paths->pubhtmldir;

    if (!defined $archivefileformat) {
	die "The WEsiteinfo->staging->archivefile config member is not defined";
    }
    if (!defined $pubhtmldir || $pubhtmldir eq '') {
	die "The publish html directory is missing (config member WEsiteinfo->paths->pubhtmldir)";
    }

    my @l = localtime;
    my $date = sprintf "%04d%02d%02d-%02d%02d%02d", $l[5]+1900, $l[4]+1, @l[3,2,1,0];
    (my $archivefile = $archivefileformat) =~ s/\@DATE\@/$date/g;

    my $tar = Archive::Tar->new();

    print "Add to archive...\n";
    _save_pwd {
	my @files;
	my %absfiles;
	my @symlinks;
	chdir $pubhtmldir or die "Can't chdir to $pubhtmldir: $!";
	File::Find::find
		(sub { 
		     return if -d;
		     # exclude:
		     return if $File::Find::name =~ m{^\./we/};
		     return if $File::Find::name =~ m{/(CVS|RCS|\.svn)/};
		     return if m{^( \.cvsignore
				  | \.keep_me # yes? no? XXX
				  | .*~
				  | \.\#.*\.\d+ # a CVS related file
				  | \.DS_Store
				  )$}x;
		     if (-l) {
			 my $readlink = readlink($_);
			 push @symlinks, [$File::Find::name, $readlink, File::Spec->rel2abs($readlink)];
		     } else {
			 print $File::Find::name, "\n";
			 push @files, $File::Find::name;
			 $absfiles{ File::Spec->rel2abs($_) } = $File::Find::name;
		     }
		 }, ".");
#XXX require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([[sort keys %absfiles], \@symlinks],[])->Indent(1)->Useqq(1)->Dump; # XXX

	for my $symlinkdef (@symlinks) {
	    my($file, $relfile, $absfile) = @$symlinkdef;
	    # XXX Archive::Tar 1.10 bug:
	    # XXX only one symlink of multiple to the same file can be
	    # stored, so use no symlinks at all...
	    if (0 && exists $absfiles{$absfile}) {
		# XXX make sure it's a relative link!
		# push @files, File::Spec->abs2rel($file, 
		print "Symlink $file -> $relfile\n";
		push @files, $file;
	    } else {
		if (!open(FH, $absfile)) {
		    print "Skipping $absfile, can't open $!\n";
		} else {
		    local $/ = undef;
		    my $buf = <FH>;
		    print "Symlink not available on target system, store data for $file\n";
		    $tar->add_data($file, $buf);
		    close FH;
		}
	    }
	}
	$tar->add_files(@files);
    };

    $tar->write($archivefile, 1, "htdocs");

    print "\nArchive file $archivefile written...\n";

    return $archivefile;
}

# Apache.pm-friendly system()
sub _system {
    my $cmd = shift;
    open(SYS, "$cmd|");
    while(<SYS>) {
	print $_;
    }
    close SYS;
}

1;

__END__

=head1 NAME

WE_Frontend::Publish::Tgz - publish files to a tar.gz archive file

=head1 SYNOPSIS

    use WE_Frontend::Main2;
    use WEsiteinfo qw($c);
    $c->staging->transport("tgz");
    $main->publish;

=head1 DESCRIPTION


=head2 WEsiteinfo.pm SETUP

The staging object of C<WEsiteinfo.pm> should be set as follows:

    $staging->transport("tgz");
    $staging->archivefile('/tmp/archive-@DATE@.tar.gz'); # @DATE@ is filled with a iso 8601 date/time

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<tar(1)>, L<gzip(1)>.

=cut

