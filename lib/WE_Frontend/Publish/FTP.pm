# -*- perl -*-

#
# $Id: FTP.pm,v 1.7 2005/02/18 14:03:39 cmuellermeta Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002 Online Office Berlin. All rights reserved.
# Copyright (c) 2002 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Publish::FTP;

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

package WE_Frontend::Main;

use strict;

use Net::FTP;

use WE_Frontend::Publish;

BEGIN {
    if ($] < 5.006) {
        $INC{"warnings.pm"}++;
        eval q{
            package warnings;
            sub unimport { }
        }; die $@ if $@;
    }
}

{
    no warnings 'redefine';
    use WE::Util::Functions qw(_save_pwd);
}

sub publish_ftp {
    my($self, %args) = @_;

    my $v = delete $args{-verbose};

    my $liveuser = $self->Config->staging->user;
    my $livepassword = $self->Config->staging->password;
    my $livedirectory = $self->Config->staging->directory;
    my $livecgidirectory = $self->Config->staging->cgidirectory;
    my $livehost = $self->Config->staging->host;
    my $pubhtmldir = $self->Config->paths->pubhtmldir;
    my @extracgi = (ref $self->Config->project->stagingextracgi eq 'ARRAY'
		    ? @{ $self->Config->project->stagingextracgi }
		    : ()
		   );

    if (!defined $liveuser || $liveuser eq '') {
	die "The FTP user is missing (config member WEsiteinfo->staging->user)";
    }
    if (!defined $livepassword || $livepassword eq '') {
	die "The FTP password is missing (config member WEsiteinfo->staging->password)";
    }
    if (!defined $livehost || $livehost eq '') {
	die "The target FTP host is missing (config member WEsiteinfo->staging->host)";
    }
    if (!defined $pubhtmldir || $pubhtmldir eq '') {
	die "The publish html directory is missing (config member WEsiteinfo->paths->pubhtmldir)";
    }
    if (@extracgi && (!defined $livecgidirectory || $livecgidirectory eq '')) {
	die "Extra CGI scripts are defined (@extracgi),
but the WEsiteinfo->staging->cgidirectory config is missing";
    }

    if ($v) {
	print <<EOF
Using FTP Protocol.
FTP remote host:          $livehost
FTP remote user:          $liveuser
FTP remote directory:     $livedirectory
@{[ @extracgi ? "FTP remote CGI directory: $livecgidirectory" : "" ]}

EOF
    }

    my $ftp = Net::FTP->new($livehost, Debug => 0) or die "Can't open FTP connection to $livehost: $@";
    $ftp->login($liveuser, $livepassword) or die "Can't login with $liveuser";
    $ftp->pasv();
    $ftp->binary();
    if (defined $livedirectory && $livedirectory ne '') {
	$ftp->cwd($livedirectory) or die "Can't remote chdir to $livedirectory";
    }

    my $ret = WE_Frontend::Publish::get_files_to_publish($self, %args);
    my @directories = @{ $ret->{Directories} };
    my @files       = @{ $ret->{Files}       };

    _save_pwd {
	chdir $pubhtmldir || die "Can't change directory to $pubhtmldir: $!";

	foreach my $dir (@directories) {
	    if ($v) { print "Create folder $dir\n" }
	    $ftp->mkdir($dir);
	}

	foreach my $file (@files) {
	    if ($v) { print "Create document $file\n" }
	    if (!-r $file) { warn "The local file $pubhtmldir/$file is not readable" }
	    $ftp->put($file, $file) or warn "Can't put $pubhtmldir/$file to remote host $livehost";
	}

    };

    return {Directories => \@directories,
	    Files       => \@files,
	   };
}

1;

__END__

=head1 NAME

WE_Frontend::Publish::FTP - publish a complete site with ftp

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

