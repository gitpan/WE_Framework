# -*- perl -*-

#
# $Id: Rsync.pm,v 1.16 2004/12/23 10:53:41 eserte Exp $
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

package WE_Frontend::Publish::Rsync;

# package WE_Frontend::Main;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

use WE_Frontend::Publish;

use File::Basename;

sub _rsyncexe {
    my $self = shift;
    ($self->Config->staging->stagingext &&
     $self->Config->staging->stagingext->{'rsyncexe'}
     ? $self->Config->staging->stagingext->{'rsyncexe'}
     : 'rsync'
    );
}

sub _deleteold {
    my $self = shift;
    ($self->Config->staging->stagingext &&
     $self->Config->staging->stagingext->{'deleteold'}
     ? $self->Config->staging->stagingext->{'deleteold'}
     : 0
    );
}

# for compatibility:
sub WE_Frontend::Main::publish_rsync {
    my($self, %args) = @_;
    publish_rsync($self, %args);
}

sub publish_rsync {
    my($self, %args) = @_;

    my $do_exec = !delete $args{-n};
    my $v = delete $args{-verbose};
    my $since = delete $args{-since};
    if (defined $since) {
	warn "The -since option is ignored with publish_rsync!";
    }
    my $liveuser = $self->Config->staging->user;
    my $livedirectory = $self->Config->staging->directory;
    my $livecgidirectory = $self->Config->staging->cgidirectory;
    my $livehost = $self->Config->staging->host;
    my $pubhtmldir = $self->Config->paths->pubhtmldir;
    my $cgidir = $self->Config->paths->cgidir;
    my @extracgi = (ref $self->Config->project->stagingextracgi eq 'ARRAY'
		    ? @{ $self->Config->project->stagingextracgi }
		    : ()
		   );
    # rsync 2.5.1 seems to be reliable, but previous version could hang.
    # So give the user the chance to change the rsync executable path.
    my $rsyncexe  = $self->WE_Frontend::Publish::Rsync::_rsyncexe;
    my $deleteold = $self->WE_Frontend::Publish::Rsync::_deleteold;

    if (defined $liveuser && !defined $livehost) {
	die "\$livehost should be also set if \$liveuser is set";
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
Using Rsync Protocol.
Rsync remote host:          @{[ defined $livehost ? $livehost : "localhost" ]}
Rsync remote user:          @{[ defined $liveuser ? $liveuser : "current" ]}
Rsync remote directory:     $livedirectory
@{[ @extracgi ? "Rsync remote CGI directory: $livecgidirectory" : "" ]}
@{[ $deleteold ? "Delete unused remote files" : "Leave unused remote files" ]}
EOF
    }

    # XXX same as in Rdist.pm
    my @cvs_exclude_pat = @{ WE_Frontend::Publish->cvs_exclude };
    my @we_exclude_pat  = @{ WE_Frontend::Publish->we_exclude };
    my @exclude_pat = (@cvs_exclude_pat, @we_exclude_pat);
    my @exclude;
    my %additional;
    if ($self->Config->project->stagingexceptpat) {
	push @exclude_pat, @{ $self->Config->project->stagingexceptpat };
    }
    if ($self->Config->project->stagingexcept) {
	push @exclude, @{ $self->Config->project->stagingexcept };
    }
#XXX not yet used:
    if ($self->Config->project->stagingadditional) {
	%additional = %{ $self->Config->project->stagingadditional };
    }

    my @directories;
    my @files;

    # first create target directories
    my @mkdircmd;
    $mkdircmd[0] = "mkdir -p $livedirectory";
    if (@extracgi) {
	$mkdircmd[0] .= "; mkdir -p $livecgidirectory";
    }
    if (defined $livehost) {
	unshift @mkdircmd, ('ssh', '-l', $liveuser, $livehost);
    }

    if (!$do_exec) {
	print join(" ", @mkdircmd), "\n";
    } else {
	_system(@mkdircmd);
    }

    my($rsync1, $rsync2, $src1, $src2, $cmd, $cmd2);
    # Don't spread confusion! Now the rsync commands are constructed.
    # They consist of
    #    $cmd  = $rsync1 $src1 $rsync2 targetdirectory1
    #    $cmd2 = $rsync1 $src2 $rsync2 targetdirectory2

    $rsync1 = $rsyncexe; # command and first parameters
    if (!$do_exec) {
	$rsync1 .= ' -n';
    }
    $rsync1 .= " -v"; # be verbose
    $rsync1 .= " -l"; # XXX check for destination system and revert to -L if necessary
    if (defined $livehost) {
	$rsync1 .= " -z"; # compress if remote
	$rsync1 .= " -e ssh"; # just in case there's an old rsync defaulting to rsh
    }
    if ($deleteold) {
	$rsync1 .= " --delete";
    }

    $src1 = ""
	# in/excludes
	. " " . join(" ", map "--exclude \"$_\"", @exclude_pat)
	. " " . join(" ", map "--exclude \"/$_\"", @exclude)
        # source
        . " -r $pubhtmldir/";

    $src2 = ""
	# in/excludes
	. " " . join(" ", map "--exclude \"/$_\"", @exclude)
	. " --exclude .cvsignore"
        # source
        . " " . join(" ", map { "$cgidir/$_" } @extracgi);

    $rsync2 = " "; # destination without directory
    if (defined $liveuser && defined $livehost) {
	$rsync2 .= " $liveuser\@$livehost:";
    }

    if ($self->Config->project->projectext &&
	$self->Config->project->projectext->{'extrastagingsub'}) {
	if ($do_exec) {
	    $self->Config->project->projectext->{'extrastagingsub'}->();
	} else {
	    print "Call subroutine " . $self->Config->project->projectext->{'extrastagingsub'} . "\n";
	}
    }

    # rsync is often in /usr/local/bin
    local $ENV{PATH} = $ENV{PATH} . ":/usr/local/bin";

    $cmd  .= "$rsync1$src1$rsync2$livedirectory";
    if (!$do_exec) {
	print "exec $cmd\n";
    } else {
	if (defined $v && $v > 1) {
	    print "Command: $cmd\n";
	}
	_system($cmd);
	if ($?/256 != 0) {
	    my $error = "Error code @{[ $?/256 ]} while doing: $cmd
PATH is $ENV{PATH}";
	    print "$error\n" if $v;
	    die $error;
	}
    }

    if (@extracgi) {
	$cmd2 = "$rsync1$src2$rsync2$livecgidirectory";
	if (!$do_exec) {
	    print "exec $cmd2\n";
	} else {
	    if (defined $v && $v > 1) {
		print "Command: $cmd2\n";
	    }
	    _system($cmd2);
	    if ($?/256 != 0) {
		my $error = "Error code @{[ $?/256 ]} while doing: $cmd2
PATH is $ENV{PATH}";
		print "$error\n" if $v;
		die $error;
	    }
	}
    }

    return;
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

sub publish_files {
    my($self, $selected_files, %args) = @_;

    my $do_exec = !delete $args{-n};
    my $v = delete $args{-verbose};

    require File::Temp;

    # rsync is often in /usr/local/bin
    local $ENV{PATH} = $ENV{PATH} . ":/usr/local/bin";

    my(@files, %dir);
    for my $file (@$selected_files) {
	push @files, $file;
	my @p = split m|/|, $file;
	for my $i (0 .. $#p-1) {
	    $dir{join "/", @p[0 .. $i]}++;
	}
    }

    my($fh, $file) = File::Temp::tempfile(UNLINK => 1);
    my @all_files = (keys(%dir), @files);
    my $include = join("\n", map { "/$_" } sort @all_files) . "\n";
    print $fh $include;
    close $fh;

    if ($v) {
	print STDERR "Include:\n$include\n";
    }

    #my @rsync_args = ("-r", "-a", "-p", "-t"); # XXX -a?
    my @rsync_args = ("-rptgoD", "-vz", "-L", "--copy-unsafe-links"); # XXX -a?
    if (!$do_exec) { push @rsync_args, "-n" }
    # if ($v)        { push @rsync_args, "-Pv" }
    if ($self->WE_Frontend::Publish::Rsync::_deleteold) {
	push @rsync_args, "--delete";
    }
	
    my $liveuser   = $self->Config->staging->user;
    my $livehost   = $self->Config->staging->host;
    my $liversakey = $self->Config->staging->rsakey;

    if (defined $liveuser && defined $liversakey){
	push @rsync_args, "-e ssh -l $liveuser -i $liversakey";
    }

    my $from = $self->Config->paths->pubhtmldir;
    $from =~ s{ (?<!/)$ }{/}x; # add trailing slash

    my $to   = $self->Config->staging->directory;
    $to   =~ s{ (?<!/)$ }{/}x; # add trailing slash
    
    if (defined $livehost) {
	$to = "$livehost:$to";
    }

    my @cmd = ($self->WE_Frontend::Publish::Rsync::_rsyncexe, @rsync_args);
    push @cmd, ("--include-from=$file", "--exclude=**");
    push @cmd, $from, $to;
    warn "@cmd";

    my $ret = 1;
    if ($do_exec) {
	system(@cmd) and do {
	    warn "Error code is $?, please see man rsync for explanation.
PATH is $ENV{PATH}";
	    $ret = 0;
	};
    }

    unlink $file;

    $ret;
}

1;

__END__

=head1 NAME

WE_Frontend::Publish::Rsync - publish files via the rsync protocol

=head1 SYNOPSIS

    use WE_Frontend::Main2;
    use WEsiteinfo qw($c);
    $c->staging->transport("rsync");
    $main->publish;

=head1 DESCRIPTION

=head1 TUTORIAL FOR RSYNC SETUP

(See also L</Update> section below)

First make sure that both sides have C<rsync> installed. Please use
version 2.5.1 or better, because there are deadlock problems with
older versions. Then SSH authentification should be setup. Do the
following:

=over 4

=item *

Create a SSH public key for the local (source) side. If the CGI
scripts are running under a special www user (such as C<wwwrun> on
Linux SuSE systems), you have first to create a home directory for
this user or let the CGI scripts run under another user.

If you do not know the uid for CGI scripts, then create this tiny
script and run it as an CGI:

    #!/usr/bin/env perl
    use CGI qw(:standard);
    print header, join(",", getpwuid($>));

The user id should be the third entry, the home directory the eighth
entry.

Assuming you want to create a home directory for C<wwwrun> (this may
be insecure!), you have to do following (all as superuser):

=over 4

=item mkdir /home/wwwrun

=item vipw

=item replace the old home directory for C<wwwrun> with
C</home/wwwrun>

=item make sure that the user has a valid shell

=item quit vipw

=back

Now change to the C<wwwuser> user by typing

    su wwwuser

and generate a ssh private/public key pair:

=over 4

=item ssh-keygen -N ""

=item cat /home/wwwrun/.ssh/identity.pub

=back

You should see the public key on the screen.

=item *

This public key should be made accessible on the remote side. Switch
to another virtual terminal or xterm, login to the remote side as the
remote user and do following:

=over 4

=item In the home directory: mkdir .ssh

=item chmod 700 .ssh

=item cd .ssh

=item cat > authorized_keys

=item copy and paste the previous public key (is it still on the
screen?) and press Control-D

=item chmod 600 authorized_keys

=back

=back

That is it! Now check whether the connection works. As C<wwwuser>,
type the following:

    ssh -v -l remoteuser remotehost

The first time, you will get a message whether to accept the host.
Accept, and then you should be automatically logged in without
prompting for a password. If not, read carefully the messages. Most
likely there is a permission problem on the local or remote side. Make
sure that permissions are as tight as possible for the files in .ssh,
and the .ssh and home directories itself.

To check whether C<rsync> works, do the following from the local side:

    rsync -Pv some_file remoteuser@remotehost:

Now C<some_file> should be copied to the remote side without prompting
for a password. If you have an old C<rsync>, you have to add C<-e ssh>
to the options (but better upgrade). If you redo the operation, the
copy should be done much faster, because they are no changes to be
transferred.

=head2 WEsiteinfo.pm SETUP

The staging object of C<WEsiteinfo.pm> should be set as follows:

    $staging->transport("rsync");
    $staging->user("remoteuser");
    # $staging->password; # not needed
    $staging->host("remotehost");
    $staging->directory("subdirectory_on_remote"); # this may be empty for the home directory
    $staging->stagingext({deleteold => 0}); # set to true if old remote files should be deleted (dangerous!)

=head2 Update

(This is not sufficiently tested)

There's no need to create a home directory for the apache user. Just create a private/public key pair:

    ssh-keygen -N "" -b 1024 -t dsa -f /tmp/id_dsa

and then

    mv /tmp/id_dsa .../webeditor/etc/id_dsa

(make sure that the etc directory is B<NOT> web accessible)

and add id_dsa.pub to ~/.ssh/authorized_keys of the rsync/ssh user on
the remove side. In the WEsiteinfo.pm configuration the liversakey and
liveuser config params has to be set:

    $staging->liveuser("remoteuser");
    $staging->liversakey(".../webeditor/etc/id_dsa");

=head1 HISTORY

Version 1.7 does not exclude C<.htaccess> files anymore. Please use
C<stagingexcept> instead.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<rsync(1)>.

=cut

