# -*- perl -*-

#
# $Id: FTP_MD5Sync.pm,v 1.5 2004/06/10 13:18:02 eserte Exp $
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

#XXX better mapping mechanism! rdist? an existing perl module?

=head1 NAME

WE_Frontend::Publish::FTP_MD5Sync - publish with FTP using MD5 fingerprints

=head1 SYNOPSIS

    use WE_Frontend::Main2;
    use WEsiteinfo qw($c);
    $c->staging->transport("ftp-md5sync");
    $main->publish;

or

    use WE_Frontend::Main;
    use WEsiteinfo;
    $WEsiteinfo::livetransport = "ftp-md5sync";
    $main->publish;

=head1 DESCRIPTION

=cut

package WE_Frontend::Publish::FTP_MD5Sync;

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

package WE_Frontend::Main;

use strict;

use Net::FTP;
use LWP::UserAgent;
use Digest::MD5;

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

sub publish_ftp_md5sync {
    my($self, %args) = @_;

    my $v = delete $args{-verbose};
    my $dryrun = delete $args{-n};

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
    my $md5listcgi = $self->Config->staging->stagingext->{'md5listcgi'};
    my $topdirectory = $self->Config->staging->stagingext->{'topdirectory'};
    my $deleteold = $self->Config->staging->stagingext->{'deleteold'};
    my $movetotrash = $self->Config->staging->stagingext->{'movetotrash'};
    my $trashdirectory = $self->Config->staging->stagingext->{'trashdirectory'};
    if ($self->Config->staging->stagingext->{'dryrun'}) {
	$dryrun++;
    }

    die "Can't use deleteold and movetotrash"
	if $deleteold && $movetotrash;
    die "movetotrash defined but there is no trashdirectory"
	if $movetotrash && !defined $trashdirectory;

=head2 WESITEINFO CONFIGURATION

This refers to the old format (first name) or the new format (second
name).

=over 4

=item $livetransport or $c->staging->transport

The transport protocol should be set to "ftp-md5sync".

=item $liveuser or $c->staging->user

The remote FTP user.

=cut

    if (!defined $liveuser || $liveuser eq '') {
	die "The FTP user is missing (config member WEsiteinfo->staging->user)";
    }

=item $livepassword or $c->staging->password

The remote FTP password.

=cut

    if (!defined $livepassword || $livepassword eq '') {
	die "The FTP password is missing (config member WEsiteinfo->staging->password)";
    }

=item $livedirectory or $c->staging->directory

The remote FTP directory. This is not the real filesystem path on the
remote host, but the virtual FTP path. For example: the real
filesystem path may be somthing like C</home/users/company>, but if
you login to the server as C<company>, you will see C</> as the FTP
root path.

If the FTP root is C</>, the value of C<$livedirectory> should be an
empty string.

=item $livehost or $c->staging->host

The remove host.

=cut

    if (!defined $livehost || $livehost eq '') {
	die "The target FTP host is missing (config member WEsiteinfo->staging->host)";
    }

=item $pubhtmldir or $c->paths->pubhtmldir

The local htdocs directory.

=cut

    if (!defined $pubhtmldir || $pubhtmldir eq '') {
	die "The publish html directory is missing (config member WEsiteinfo->paths->pubhtmldir)";
    }

=item $livecgidirectory or $c->staging->cgidirectory

If there are CGI programs to be published, the remote cgi directory
have to be specified. The same rules as in C<$livedirectory> apply.

=item @stagingextracgi or $c->project->stagingextracgi

An array reference with additional cgi scripts to be published.

=cut

    if (@extracgi && (!defined $livecgidirectory || $livecgidirectory eq '')) {
	die "Extra CGI scripts are defined (@extracgi),
but the WEsiteinfo->staging->cgidirectory config is missing";
    }

=item $livestagingext or $c->staging->stagingext

A hash reference with additional attributes:

=over 4

=item dryrun

If set to a true value, then do not execute the FTP commands, just
show them.

=item md5listcgi

The remote CGI script to create the MD5 list. The script is included
in the C<WE_Framework> as C<cgi-scripts/get_md5_list.cgi>.

=item topdirectory

The top directory of the remote server. Here the real filesystem path
should be used. In the example above, this would be
C</home/users/company>.

=item deleteold

If true, then outdated remote files (not existing on the local side)
are deleted.

=item movetotrash

If true, then outdated remote files will be moved to the
C<trashdirectory>. Cannot be used together with C<deleteold>.

=item trashdirectory

The FTP directory name of a trash directory. Have to be defined if
C<movetotrash> is set.

=back

=back

=head2 GETMD5LIST.CGI CONFIGURATION

The CGI script C<get_md5_list.cgi> is configured by creating a perl
file called C<get_md5_list.cgi.config> which should reside in the same
directory as the CGI script. The following perl variables may be set
as configuration variables:

=over 4

=item @directories

A list of directories for which the MD5 fingerprints should be
collected. Normally these are C<livedirectory> and C<livecgidirectory>
from the C<WEsiteinfo> configuration.

=item @digest_method

Specify a list with the preferred methods to get the MD5 digest. This does not need to be set; C<get_md5_list.cgi> is smart enough to get a supported method automatically. Permitted values are:

=over

=item 'perl:Digest::MD5'

Use the perl module L<Digest::MD5|Digest::MD5>.

=item 'perl:MD5'

Use the (old) perl module L<MD5|MD5>.

=item 'cmd:md5'

Use the OS command C<md5> (BSD systems).

=item 'cmd:md5sum'

Use the OS command C<md5sum> (Linux and Solaris systems).

=item 'perl:Digest::Perl::MD5'

Use the pure perl module L<Digest::Perl::MD5|Digest::Perl::MD5>.

=item 'cmd:cksum'

Use the obsolete C<chksum> command.

=item 'stat:modtime'

Just stat the file and use the modification time of the file.

=back

=item @exclude

A list of files to be excluded. The check will be done against the
partial filename, beginning at the paths as in C<@directories>.

=item %exclude

Per-directory (as in C<@directories>) exclude list. For example, if

    @directories = ("/home/htdocs", "/home/htdocs/cgi-bin");

is specified, then C<%exclude> may be

    %exclude = ("/home/htdocs" => ['.htaccess', 'cgi-bin/.*'],
                "/home/htdocs/cgi-bin" => ['mails.*']);

Note that it is generally problematic to have subdirs specified in
C<@directories> --- in such a case the C<%exclude> variable should be
set cleverly.

=item $verbose

Be verbose if set to a true value. The messages are printed to STDERR.
Note that some servers do not like output to STDERR --- it will get
mixed up with STDOUT output.

=back

=cut

    if (!defined $md5listcgi || $md5listcgi eq '') {
	die "The CGI path to the md5list script is not defined";
    }
    if (!defined $topdirectory) {
	die "The topdirectory is missing (config member WEsiteinfo->staging->stagingext->{topdirectory})";
    }

    if ($v) {
	print <<EOF;
Using FTP Protocol.
FTP remote host:          $livehost
FTP remote user:          $liveuser
FTP remote directory:     $livedirectory
@{[ @extracgi ? "FTP remote CGI directory: $livecgidirectory" : "" ]}
md5list CGI:              $md5listcgi
topdirectory:             $topdirectory
@{[ $dryrun ? "Do not execute any create/update/delete actions, just show them" : "" ]}
EOF
        if ($deleteold) {
	    print "delete old files\n";
	} elsif ($movetotrash) {
	    print "move old files to trash directory: $trashdirectory\n";
	} else {
	    print "keep old files\n";
	}
    }

    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new('GET', $md5listcgi);
    my $res = $ua->request($request);
    #my $res = $ua->get($md5listcgi);
    if (!$res->is_success) {
	print $res->error_as_HTML;
	die "Can't get MD5 list from $md5listcgi";
    }

    my %md5list;
    my $curr_dir;
    foreach my $line (split /\n/, $res->content) {
	if ($line =~ /^\#\s*([^:]+):\s*(.*)/) {
	    my($key,$val) = ($1,$2);
	    if ($key =~ /^digest$/i) {
		if ($val !~ /md5/i) {
		    die "Sorry, only MD5 digest are supported now";
		}
	    } elsif ($key =~ /^directory$/i) {
		$curr_dir = $val;
	    } else {
		# ignore
	    }
	} else {
	    if (!defined $curr_dir) {
		die "Current directory is not defined ( $line )";
	    }
	    my($file, $md5) = split /\t/, $line;
	    $md5list{$curr_dir}->{$file} = $md5;
	}
    }

    if ($v) {
	print "Got MD5 list from $md5listcgi:\n";
	require Data::Dumper;
	print Data::Dumper->Dumpxs([\%md5list],['md5list']), "\n";
    }

    my $ftp = Net::FTP->new($livehost, Debug => 0) or die $@;
    $ftp->login($liveuser, $livepassword) or die "Can't login with $liveuser";
    $ftp->binary();
    if (defined $livedirectory && $livedirectory ne '') {
	$ftp->cwd($livedirectory) or die "Can't remote chdir to $livedirectory";
	if ($dryrun) {
	    print "Execute chdir $livedirectory, now in directory: " . $ftp->pwd . "\n";
	}
    }

    my $pub_files = WE_Frontend::Publish::get_files_to_publish($self, %args);
    my @directories = @{ $pub_files->{Directories} };
    my @files       = @{ $pub_files->{Files}       };
    my @published_files;

    my $remotedir = ($topdirectory ne "" ? "$topdirectory/" : "") . $livedirectory;
    $remotedir =~ s|/+|/|g;

    # Ack! This will fetch all local files and directories, regardless
    # whether it is new or old
    my %args2 = %args;
    delete $args2{-since}; # get really all!
    $pub_files = WE_Frontend::Publish::get_files_to_publish($self, %args2);
    my %local_files = map { ("$remotedir/$_" => 1) } @{ $pub_files->{Files} };

    my @files_to_delete;
    foreach my $dir (keys %md5list) {
	foreach my $file (keys %{$md5list{$dir}}) {
	    if (!exists $local_files{"$dir/$file"}) {
		(my $remotefile = "$dir/$file") =~ s|^\Q$remotedir\E/?||;
		push @files_to_delete, $remotefile;
	    }
	}
    }

    _save_pwd {
	chdir $pubhtmldir || die $!;

	# XXX only create directories if really necessary!
	foreach my $dir (@directories) {
	    if ($v) { print "Create folder $dir\n" }
	    if (!$dryrun) {
		$ftp->mkdir($dir);
	    } else {
		print "Execute mkdir $dir\n";
	    }
	}

	foreach my $file (@files) {
	    if (!-r $file) { warn "The local file $pubhtmldir/$file is not readable" }

	    my $message = "Create document $remotedir | $file\n";
	    my $copy = 1;
	    if (exists $md5list{$remotedir}->{$file}) {
		my $md5 = Digest::MD5->new;
		open(F, $file) or die "Can't read file $file: $!";
		$md5->addfile(\*F);
		close F;
		my $local_md5 = $md5->hexdigest;
		if ($local_md5 eq $md5list{$remotedir}->{$file}) {
		    $copy = 0;
		    if ($v) { print "skipping document $file\n" }
		} else {
		    $message = "Update document $file\n";
		}
	    }

	    if ($copy) {
		if ($v) { print $message }
		if (!$dryrun) {
		    $ftp->put($file, $file) or warn "Can't put $pubhtmldir/$file to remote host $livehost";
		} else {
		    print "Execute put $file to $file\n";
		}
		push @published_files, $file;
	    }
	}

    };

    # see, which files are left to delete.
    my @deleted_on_remote;
    my @moved_to_trash_on_remote;
    if ($deleteold) {
	foreach my $file (@files_to_delete) {
	    if ($v) { print "deleting remote file $file\n"; };
	    if (!$dryrun) {
		$ftp->delete($file) or warn "Can't delete $pubhtmldir/$file on remote host $livehost\n";
	    } else {
		print "Execute delete $file\n";
	    }
	    push @deleted_on_remote, $file;
	}
    } elsif ($movetotrash) {
	require File::Basename;
	foreach my $file (@files_to_delete) {
	    if ($v) { print "move remote file $file to $trashdirectory\n"; };
	    my $basefile = File::Basename::basename($file);
	    if (!$dryrun) {
		$ftp->rename($file, "$trashdirectory/$basefile") or warn "Can't rename $file to $trashdirectory/$basefile on remote host $livehost\n";
	    } else {
		print "Execute rename $file to $trashdirectory/$basefile\n";
	    }
	    push @moved_to_trash_on_remote, $file;
	}
    } elsif (@files_to_delete && $v) {
	print "The following files are outdated on the remote:\n",
	    join(", ", @files_to_delete), "\n";
    }

    my $ret = {Directories     => \@directories,
	       Files           => \@files,
	       PublishedFiles  => \@published_files,
	       DeletedOnRemote => \@deleted_on_remote,
	       MovedToTrashOnRemote => \@moved_to_trash_on_remote,
	      };
    return $ret;
}

1;

__END__

=head1 CAVEAT

There are still some problems with this module. Be especially careful
if using the C<deleteold> feature.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut


