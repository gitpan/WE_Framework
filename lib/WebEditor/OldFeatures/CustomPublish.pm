# -*- perl -*-

#
# $Id: CustomPublish.pm,v 1.3 2004/06/07 06:58:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
#

package WebEditor::OldFeatures::CustomPublish;

# This serves as a template for custom rsync-based publishing.

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"}++;
	eval q{
	    package warnings;
	    sub unimport { }
	}; die $@ if $@;
    }
}

sub do_publish {
    my($self, %args) = @_;

    require File::Basename;
    require File::Spec;
    require File::Find;
    require File::Temp;

    no warnings; # # in qw()

    my $c = $self->C;
    my $v = delete $args{-verbose} || 0;

    my @files;

    my $rootdir = $c->paths->uprootdir;
    my $projectname = $c->project->name;

    my $dbg = 1;

    # Can't use "follow => 1", because this will skip files if they
    # are already listed though their symlink. However, the semantics of
    # follow_fast is not totally clear.
    File::Find::find({follow_fast => 1, # needed for common/perl
		      follow_skip => 2, # do not die on duplicates
		      wanted => sub {
	$File::Find::prune = 1, return if $_ =~ m{^( core\..*
						   | \.core
						   | \#.*
						   | \.\#.*
						   | ,.*
						   | \.cvsignore
						   | \.AppleDouble
						   | .*\.bak
						   | .*~
						   )$}x;
	return if -d $_;
        my $path = substr($File::Find::name, length($rootdir)+1);
	print STDERR "$path " if $dbg;
	do {
	    $File::Find::prune = 1;
	    goto CLEANUP;
	} if $path !~ m{^( cgi-bin/
		         | etc/
			 | lib/
			 | htdocs/
			 | we_data/
			 | conf/
			 | common/
			 )}x;
	print STDERR "1" if $dbg;
	goto CLEANUP if $path =~ m{( ^htdocs/index\.html$
			     	   | ^cgi-bin/we_redisys\.cgi$
			           | ^cgi-bin/WEsiteinfo_$projectname\.pm$
			           | ^cgi-bin/WEsiteinfo\.pm$
			           )}x;
	print STDERR "2" if $dbg;
	goto CLEANUP if ($path =~ m{^htdocs/we/} &&
		   	 $path !~ m{^htdocs/we/${projectname}_templates/search_result});
	print STDERR "3" if $dbg;
	goto CLEANUP if ($path =~ m{^we_data/} &&
		   	 $path !~ m{^we_data/[^/]+\.db});
	print STDERR "4" if $dbg;
	goto CLEANUP if ($path =~ m{^conf/} &&
		   	 $path !~ m{^conf/htdig\.tpl\.conf$});
	print STDERR "5" if $dbg;
	goto CLEANUP if ($path =~ m{^etc/} &&
		   	 $path !~ m{^etc/run_indexer$});
	print STDERR "6" if $dbg;
	push @files, $path;
    CLEANUP:
	print STDERR "\n" if $dbg;
    }}, $rootdir);

    my %dir;
    for my $f (@files) {
	my @dirs = File::Spec->splitdir($f);
	pop @dirs;
	for my $d_i (0 .. $#dirs) {
	    $dir{ File::Spec->catdir(@dirs[0 .. $d_i]) }++;
	}
    }

    my($fh, $file) = File::Temp::tempfile(SUFFIX => ".rsync.txt",
					  #UNLINK => 1,
					 );
    print $fh join("\n", map { "/$_" } sort (keys(%dir), @files)), "\n";

    local $ENV{PATH} = "$ENV{PATH}:/usr/bin:/usr/local/bin";
    no warnings 'qw'; # no perl 5.00503 compat here

    my @common_rsync_args =
	(qw(rsync -rptgoD -vz --copy-unsafe-links),
	 "-e", "ssh",
	);
    my @common_exc =
	qw(--cvs-exclude
	   --exclude core --exclude #* --exclude .#*
	   --exclude ,* --exclude .cvsignore
	   --exclude .AppleDouble/);
    my @cmds =
	(
	 {label => "HTML-Seiten, CGI-Skripte, Perl-Libraries, Datenbank, htdig-conf",
	  cmd => [@common_rsync_args, @common_exc,
		  ("--include-from=$file", "--exclude=**"),
		  $c->paths->uprootdir . "/",
		  $c->staging->host . ":" . File::Basename::dirname($c->staging->directory) . "/",
		 ]
	 },
	);
    for my $cmddef (@cmds) {
	my $label = $cmddef->{label};
	my @cmd   = @{ $cmddef->{cmd} };
	print "--- $label ---\n";
	print "@cmd\n\n" if $v;
	warn "@cmd\n";
	system(@cmd);
	if ($? != 0) {
	    warn "\n\nWarnung: es wurden Fehler bei der Übetragung festgestellt!\n";
	}
    }
}

1;

__END__
