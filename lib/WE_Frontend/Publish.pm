# -*- perl -*-

#
# $Id: Publish.pm,v 1.7 2004/06/10 13:18:02 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Publish;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use File::Find;
use File::Basename;

use WE::Util::Functions qw(_save_pwd);

=head1 NAME

WE_Frontend::Publish - common used variables

=head1 SYNOPSIS

    use WE_Frontend::Publish;

=head1 DESCRIPTION

=over 4

=item cvs_exclude

Return a list of exclude files for publish methods. This is the same as
CVS is ignoring by default.

=cut

sub cvs_exclude {
    [qw(RCS SCCS CVS  CVS.adm  RCSLOG  .svn cvslog.*  tags  TAGS
	.make.state  .nse_depinfo  *~ *.old *.bak
	*.BAK *.orig *.rej .del-* *.a *.o  *.obj  *.so  *.Z
	*.elc *.ln core), '#*', '.#*', ',*'];
}

# hmmm... I can't get the rdist regex right, so use only a minimal version
# of cvs_exclude
sub _min_cvs_exclude {
    [qw(RCS CVS .svn *~ *.old *.bak *.BAK *.orig)];
}

=item we_exclude

Return a list of additional exclude files related to the web.editor

=cut

sub we_exclude {
    [qw(.cvsignore cgi-bin/ we/)];
}

=item get_files_to_publish($frontend_object, %args)

Return a list of files and directories to publish to the remote side. This
is a static method.

=cut

sub get_files_to_publish {
    my($self, %args) = @_;

    my $since = delete $args{-since};
    my $pubhtmldir = $self->Config->paths->pubhtmldir;
    my @extracgi = (ref $self->Config->project->stagingextracgi eq 'ARRAY'
		    ? @{ $self->Config->project->stagingextracgi }
		    : ()
		   );

    my @cvs_exclude = @{ WE_Frontend::Publish->cvs_exclude };
    my @we_exclude  = @{ WE_Frontend::Publish->we_exclude };

    my @directories;
    my @files;

    my @cgi_directories;
    my @cgi_files;

    my $skip_file = sub {
	if (defined $since) {
	    my(@s) = stat $_;
	    if (!@s) {
		warn "Can't stat file $_: $!";
		return 1;
	    }
	    if ($s[9] <= $since) { # old file, don't publish
		return 1;
	    }
	}
	0;
    };

    my $wanted = sub {
	return if $_ eq '.' || $_ eq '..';
	foreach my $exc_ (@cvs_exclude, @we_exclude) {
	    my $exc = $exc_;
	    if ($_ eq $exc) {
		if (-d $_) {
		    $File::Find::prune = 1;
		}
		return;
	    }
	    $exc =~ s/\./\\./g;
	    $exc =~ s/\*/.*/g;
	    $exc =~ s|/$||;
	    if ($_ =~ /^$exc$/) {
		if (-d $_) {
		    $File::Find::prune = 1;
		}
		return;
	    }
	}
	(my $name = $File::Find::name) =~ s|^\./||;
	if (-d $_) {
	    push @directories, $name;
	} else {

	    return if $skip_file->($_);

	    push @files, $name;
	}
    };

    _save_pwd {
	chdir $pubhtmldir || die $!;
	find($wanted, ".");

	push @directories, @{ $args{-adddirectories} }
	    if $args{-adddirectories};
	push @files, @{ $args{-addfiles} }
	    if $args{-addfiles};

	if (@extracgi) {
	    foreach my $cgi (@extracgi) {
		my $f = "cgi-bin/$cgi";
		my $dir = dirname($f);
		if (!$skip_file->($f)) {
		    push @files, $f
			if (!grep { $f eq $_ } @files);
		}
		push @directories, $dir
		    if (!grep { $dir eq $_ } @directories);
	    }
	}

	# to make sure that parent directories are always created before
	# the children directories
	@directories = sort { length($a) <=> length($b) } @directories;
    };

    return {Directories => \@directories,
	    Files       => \@files,
	   };

}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

