#!/usr/bin/env perl
# -*- Mode: cperl -*-
#----------------------------------------------
#
# $Id: sample_we_redisys.cgi,v 1.1 2003/12/04 17:55:30 eserte Exp $
#
#  we_redisys.cgi is part of the "web editor"
#  this is under the GPL
#  oleberlin@users.sourceforge.net
#
#----------------------------------------------

use strict;

BEGIN {
    # Netscape, Roxen and Apache 2.0.something do not like warnings...
    if (defined $ENV{SERVER_SOFTWARE} &&
	$ENV{SERVER_SOFTWARE} =~ m{(netscape|roxen|apache/2\.0)}i
       ) {
	#$SIG{__WARN__} = sub { };
	open(STDERR, ">>/tmp/we_redisys_stderr.log");
	print STDERR "--- Begin at @{[ scalar localtime ]} ---\n";
    } else {
	$^W = 1;
    }
}

BEGIN {
    if ($] > 5.006) {
	eval q{
	    if (${^TAINT}) {
	        require Cwd;
		my $cwd = Cwd::cwd();
		($cwd) = $cwd =~ /^(.*)$/;
		push @INC, $cwd;
	    }
        }; die $@ if $@;
    }
}

use WEsiteinfo;
use WebEditor::OldController;

my $oc = WebEditor::OldController->new;

$SIG{__DIE__} = sub {
    # Hack: check if there is an eval in the call stack. In this
    # case a normal "die" is called.
    my $stack_i = 1;
    while($stack_i < 200) {
	my @c = caller($stack_i);
	last if !@c;
	if ($c[3] eq '(eval)') {
	    die @_;
	}
	$stack_i--;
    }
    $oc->error($_[0]);
};

$oc->handle(WEsiteinfo::get_config());
