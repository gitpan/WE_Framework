# -*- perl -*-

#
# $Id: Rdist.pm,v 1.8 2004/03/08 10:44:59 eserte Exp $
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

package WE_Frontend::Publish::Rdist;

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

package WE_Frontend::Main;

use strict;

use WE_Frontend::Publish;

use File::Basename;

sub publish_rdist {
    my($self, %args) = @_;

    my $do_exec = !delete $args{-n};
    my $v = delete $args{-verbose};
    my $since = delete $args{-since};
    if (defined $since) {
	warn "The -since option is ignored with publish_rdist!";
    }
    my $liveuser = $self->Config->staging->user;
    if ($liveuser eq '') {
	undef $liveuser;
    }
    my $livedirectory = $self->Config->staging->directory;
    my $livecgidirectory = $self->Config->staging->cgidirectory;
    my $livehost = $self->Config->staging->host;
    if (!defined $livehost || $livehost eq '') {
	$livehost = "localhost";
    }
    my $pubhtmldir = $self->Config->paths->pubhtmldir;
    my $cgidir = $self->Config->paths->cgidir;
    my @extracgi = (ref $self->Config->project->stagingextracgi eq 'ARRAY'
		    ? @{ $self->Config->project->stagingextracgi }
		    : ()
		   );
    my $distfile = ($self->Config->staging->stagingext &&
		    $self->Config->staging->stagingext->{'distfile'}
		    ? $self->Config->staging->stagingext->{'distfile'}
		    : undef);
    my @extra_args;
    if (exists $args{-transport}) {
	my $exec = is_in_path($args{-transport});
	if (!defined $exec) {
	    die "Cannot find executable for $args{-transport} in $ENV{PATH}";
	}
	push @extra_args, "-P", $exec;
	delete $args{-transport};
    }
    my $deleteold = ($self->Config->staging->stagingext &&
		     $self->Config->staging->stagingext->{'deleteold'}
		     ? $self->Config->staging->stagingext->{'deleteold'}
		     : 0);

    if (!defined $distfile) {
	if (!defined $livedirectory) {
	    die "\$livedirectory is not defined";
	}
	if (!defined $pubhtmldir || $pubhtmldir eq '') {
	    die "The publish html directory is missing (config member WEsiteinfo->paths->pubhtmldir)";
	}
	if (@extracgi && (!defined $livecgidirectory || $livecgidirectory eq '')) {
	    die "Extra CGI scripts are defined (@extracgi),
but the WEsiteinfo->staging->cgidirectory config is missing";
	}
    }

    # XXX same as in Rsync.pm
    my @cvs_exclude_pat = @{ WE_Frontend::Publish->_min_cvs_exclude }; # XXX!
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
    if ($self->Config->project->stagingadditional) {
	%additional = %{ $self->Config->project->stagingadditional };
    }

    if ($v) {
	print <<EOF;
Using rdist.
Rdist remote host:          $livehost
Rdist remote user:          @{[ defined $liveuser ? $liveuser : "current" ]}
Rdist remote directory:     $livedirectory
EOF
	if (@extracgi) {
	    print "Rdist remote CGI directory: $livecgidirectory\n";
	}
	print ($deleteold ? "Delete unused remote files\n" : "Leave unused remote files\n");
	if (@exclude) {
	    print "Exclude files:              @exclude\n";
	}
	if (@exclude_pat) {
	    print "Exclude patterns:           @exclude_pat\n";
	}
	if (%additional) {
	    print "Additional files:           ",
		  join(", ", map { "$_ => $additional{$_}" } keys %additional),
		  "\n";
	}
	print "\n";
    }

    my $dest = (defined $liveuser ? "$liveuser\@" : "") . $livehost;

    my @directories;
    my @files;

    my $diststring;
    my @additional_cmd;
    if (!$distfile) {
	$distfile = "-";

	my $exclude_pat_string = "";
	my $exclude_string = "";
	my @additional_install_string = ();

	if (@exclude_pat) {
	    $exclude_pat_string = "\texcept_pat (" .
		join("\n", map { "\t\t     " . glob2rx($_) } @exclude_pat) .
		    "\n\t\t   );\n";
	}
	if (@exclude) {
	    $exclude_string = "\texcept (" .
		join("\n", map { "\t\t     " . "$pubhtmldir/$_" } @exclude) .
		    "\n\t\t   );\n";
	}
	if (%additional) {
	    my $i = 1;
	    while(my($k, $v) = each %additional) {
		my $label = "additional$i";
		push @additional_cmd, $label;
		push @additional_install_string, <<EOF;
$label:
$pubhtmldir/$k -> $dest
	install ${livedirectory}/$v ;

EOF
		$i++;
	    }
	}

	# dump rdist bug? There have to be more than one file!
	if (@extracgi == 1) {
	    push @extracgi, @extracgi;
	}

	my $cgi_files = join(" ", map { "$cgidir/$_" } @extracgi);

	$diststring = <<EOF;
# distfile for publishing edit to www

HTDOCS = ( $pubhtmldir )
CGIFILES = ( $cgi_files )

#
# htdocs
#
htdocs:
\${HTDOCS} -> $dest
	install ${livedirectory} ;
$exclude_pat_string
$exclude_string

@{[ join("\n", @additional_install_string) ]}

#
# cgi-bin
#
cgi:
\${CGIFILES} -> $dest
	install ${livecgidirectory} ;

EOF

        if ($v) {
	    my $line = 1;
	    warn join("\n", map { $line++." ".$_} split /\n/, $diststring);
	}
    }

    my $cmd = "rdist -f $distfile";
    if (!$do_exec) {
	$cmd .= " -n";
    }
    if ($deleteold) {
	$cmd .= " -oremove";
    }

    $cmd .= " " . join(" ", qw(htdocs cgi), @additional_cmd);

    if ($distfile eq '-') {
	warn $cmd if $v;
	open(RDIST, "| $cmd") or die $!;
	print RDIST $diststring;
	close RDIST;
    } else {
	system($cmd);
	die "Error while executing $cmd" if $?/256!=0;
    }

    return;
}

sub glob2rx {
    my $glob = shift;
    my %glob2rx = ("*" => ".*",
		   "." => "\\.",
		   "#" => "\\#",
		  ); # XXX more to follow
    $glob =~ s/([\.\*\#])/$glob2rx{$1}/g;
    $glob = ".*/" . $glob . ".*";
    $glob =~ s/\Q.*.*/.*/g;
    $glob;
}

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

1;

__END__

=head1 NAME

WE_Frontend::Publish::Rdist - publish files via rdist protocol

=head1 SYNOPSIS

    use WE_Frontend::Main2;
    use WEsiteinfo qw($c);
    $c->staging->transport("rdist");
    $main->publish;

=head1 DESCRIPTION

Please note that you need rsh authentification (C<.rhosts>) setup to
use rdist over remote hosts. If instead C<ssh> transport is wished,
then the C<transport> config member should be set to C<rdist-ssh>, and
the C<ssh> setup notes in L<WE_Frontend::Publish::Rsync> apply.

=head2 WEsiteinfo.pm SETUP

The staging object of C<WEsiteinfo.pm> should be set as follows:

    $staging->transport("rdist");
    # $staging->transport("rdist-ssh"); # to use ssh instead of rsh
    $staging->user("remoteuser"); # or leave empty if on same host
    $staging->host("remotehost"); # or leave empty if on same host
    $staging->directory("subdirectory_on_remote for htdocs");
    $staging->cgidirectory("subdirectory_on_remote for cgi-bin");
    $project->stagingextracgi(["we_redisys.cgi", "..."]); # for cgi scripts
    $project->stagingexcept(["index.html", "..."]); # exclude in htdocs
    $project->stagingexceptpat(["*.pdf", "..."]); # exclude globs in htdocs
    $project->stagingadditional({"index-live.html" => "index.html"}); # additional files with renaming (these should/could be also excluded!)
    $staging->stagingext({deleteold => 0}); # set to true if old remote files should be deleted (dangerous!)

If the C<stagingext> member contains the key-value pair C<distfile>,
then this is used as the C<Distfile> for C<rdist>.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<rdist(1)>.

=cut

