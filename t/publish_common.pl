# -*- perl -*-

#
# $Id: publish_common.pl,v 1.4 2003/08/17 19:57:28 eserte Exp $
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

# common tests for 97_(new_)frontend.t

if ($^O eq 'MSWin32') {
    # skip everything
    skip("Not supported on Windows",1) for 1..$tests;
    exit;
}

my $local_test = ($testname eq "local_rsync_publish");

if (!$local_test && !eval 'getpwnam("dummy")') {
    skip("You need a dummy user with dummy password and
a ".$stagingdir." directory in his homedirectory.",1) for 1..$tests;
    exit;
}

# Change foo.html to make sure that we really did a upload
open(FOO, ">$FindBin::RealBin/testhtml/foo.html") or
    die "Can't write to foo.html";
my $text = time . rand();
print FOO $text;
close FOO;

# $is_rsync is really rsync or rdist*
my $is_rsync = $fe->Config->staging->transport =~ /^(rsync|rdist)/;
my $is_rdist = $fe->Config->staging->transport =~ /^rdist/;
my $is_local_rsync = $is_rsync && !defined $fe->Config->staging->host;
my($res);
$@ = "";
eval {
    $res = $fe->publish;
};
ok($@, "");

skip($is_rsync, ref $res eq 'HASH', 1);
skip($is_rsync, ref $res->{Directories} eq 'ARRAY', 1);
skip($is_rsync, ref $res->{Files} eq 'ARRAY', 1);

if ($is_rsync) {
    skip("Not for rsync",1) for 1..2;
} else {
    ok(scalar @{ $res->{Files} }, 5);
    ok(scalar @{ $res->{Directories} }, 3);
}

{
    my($dummydir) = ($is_local_rsync || $is_rdist || $local_test
		     ? ""
		     : (getpwnam("dummy"))[7] . "/") . $stagingdir;

    my(%files)       = map {($_=>1)} @{ $res->{Files} };
    my(%directories) = map {($_=>1)} @{ $res->{Directories} };

    foreach my $f (qw(en/html/1.html en/html/1.gif foo.html bla.html cgi-bin/bla.cgi)) {
	skip($is_rsync, exists $files{$f}, 1);
	ok(-e "$dummydir/$f", 1, "Checking for existance of $dummydir/$f");
	ok(-f "$dummydir/$f", 1, "Checking for file-ness of $dummydir/$f");
    }
    foreach my $d (qw(en en/html cgi-bin)) {
	skip($is_rsync, exists $directories{$d}, 1);
	ok(-e "$dummydir/$d", 1, "Checking for existance of $dummydir/$d");
	ok(-d "$dummydir/$d", 1, "Checking for dir-ness of $dummydir/$d");
    }

    ok(!-e "$dummydir/cgi-bin/we_redisys.cgi", 1, "we_redisys.cgi should NOT be copied");

    ok(open(FOO, "$dummydir/foo.html"), 1);
    local $/ = undef;
    my $remote_text = scalar <FOO>;
    ok($remote_text, $text);
    close FOO;
}

{
    my $now = time;
    my($res) = $fe->publish(-since => $now);

    skip($is_rsync, ref $res eq 'HASH', 1);
    skip($is_rsync, ref $res->{Directories} eq 'ARRAY', 1);
    skip($is_rsync, ref $res->{Files} eq 'ARRAY', 1);

    if ($is_rsync) {
	skip(1,1) for 1..2;
    } else {
	ok(scalar @{ $res->{Files} }, 0, "Expected zero files, but got those: @{ $res->{Files} }");
	ok(scalar @{ $res->{Directories} }, 3);
    }
}

__END__
