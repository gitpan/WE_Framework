#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 98_we_installer.t,v 1.1.1.1 2002/08/06 18:35:01 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use vars qw($tests);

use WE_Frontend::Installer;
use FindBin;
use File::Spec;
use File::Basename;
use SelectSaver;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    $tests = 12;
}

BEGIN { plan tests => $tests }

sub _save_pwd (&);

ok(1);

my $wwwroot = "$ENV{HOME}/public_html/testproject/wwwroot";
my $cgibin  = "$wwwroot/cgi-bin";
my $destfile = File::Spec->can("rel2abs") ? File::Spec->rel2abs("$FindBin::RealBin/servicepack.tar.gz") : "$FindBin::RealBin/servicepack.tar.gz";
unlink $destfile;

if (-d $cgibin) {
    _save_pwd {
	chdir $cgibin or die "Can't chdir to $cgibin: $!";
	WE_Frontend::Installer->create_servicepack($destfile);
	ok(-f $destfile);
	ok(-s $destfile);
	if ($^O ne 'MSWin32') {
	    system("tar tfvz $destfile | grep $WE_Frontend::Installer::magicfile 2>&1 >/dev/null");
	    ok($?/256, 0);
	    system("tar tfvz $destfile | grep cgi-bin/we_redisys.cgi 2>&1 >/dev/null");
	    ok($?/256, 0);
	} else {
	    skip(1,1) for (1..2);
	}

	my $since_tests = 3;
	if (eval { require Date::Parse } ) {
	    # get all top level files in $wwwroot/cgi-bin:
	    my @f = grep { -f $_ } glob("$wwwroot/cgi-bin/*");
	    # sort by modtime using ST
	    @f = map  { $_->[1] }
		sort { $a->[0] <=> $b->[0] }
		    map  { [(stat($_))[9], $_] } @f;
	    unlink $destfile;
	    WE_Frontend::Installer->create_servicepack($destfile, -since => scalar localtime ((stat($f[0]))[9]));
	    ok(-s $destfile);
	    if ((stat($f[0]))[9] != (stat($f[-1]))[9] && $^O ne 'MSWin32') {
		system("tar tfvz $destfile | fgrep -- '@{[ basename $f[0] ]}' 2>&1 >/dev/null");
		ok($?/256 != 0, 1, "$f[0] unexpected in servicepack");
		if ($f[-1] =~ /WEsiteinfo.*pm/) {
		    # was für ein Zufall...
		    ok(1);
		} else {
		    system("tar tfvz $destfile | fgrep -- '@{[ basename $f[-1] ]}' 2>&1 >/dev/null");
		    ok($?/256, 0, "$f[-1] not in servicepack");
		}
	    } else {
		skip(1,1) for (2..$since_tests);
	    }
	} else {
	    skip(1,1) for (1..$since_tests);
	}

	{
	    my $saver = new SelectSaver(\*STDOUT);
	    open(NULL, ">".File::Spec->devnull) or die $!;
	    select NULL;
	    WE_Frontend::Installer->main();
	    ok(1);

	    push @INC, $cgibin; # see WE_Frontend::Installer
	    my $self = WE_Frontend::Installer->new;
	    require WE_Frontend::MainAny;
	    $self->Main(WE_Frontend::MainAny->new);
	    ok($self->Main->isa("WE_Frontend::Main"));
	    ok($self->isa("WE_Frontend::Installer"));

	    eval { $self->upload_form };
	    ok($@,"");
	}
	# XXX don't test ->handle_tar or ->install yet!

    };
} else {
    skip(1, 1) for (2..$tests);
}

unlink $destfile;

# REPO BEGIN
# REPO NAME save_pwd /home/e/eserte/src/repository 
# REPO MD5 7f59b47ca12f3affcf409af03c44292e

=head2 _save_pwd(sub { ... })

=for category File

Save the current directory and assure that outside the block the old
directory will still be valid.

=cut

sub _save_pwd (&) {
    my $code = shift;
    require Cwd;
    my $pwd = Cwd::cwd();
    eval {
	$code->();
    };
    my $err = $@;
    chdir $pwd or die "Can't chdir back to $pwd: $!";
    die $err if $err;
}
# REPO END

__END__
