#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 70_frontend_info.t,v 1.4 2004/08/26 14:55:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use WE_Frontend::Info;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 15 }

{
    my $paths = WEsiteinfo::Paths->new;
    $paths->we_htmlbase("htmlbase");
    ok($paths->we_htmlbase, "htmlbase");
    ok($paths->we_htmldir, "htmlbase");
    $paths->we_database("database");
    ok($paths->we_database, "database");
    ok($paths->we_datadir, "database");
    $paths->servername("editorhost");
    ok($paths->servername, "editorhost");
    $paths->liveservername("livehost");
    ok($paths->liveservername, "livehost");
    ok($paths->hosturl, "http://editorhost");
    ok($paths->livehosturl, "http://livehost");
}

{
    # Do cascades work?
    my $siteinfo = WEsiteinfo->new;
    my $paths = WEsiteinfo::Paths->new;
    $paths->{_parent} = $siteinfo;
    my $project = WEprojectinfo->new;
    $project->name("my_test_project");
    $siteinfo->project($project);

    ok(UNIVERSAL::isa($project->features, "HASH"));
    $project->features({ synonym => 1 });
    ok(UNIVERSAL::isa($project->features, "HASH"));
    ok($project->features->{synonym});

    $paths->uprootdir("Root Of All");
    ok($paths->we_htmlbase, "Root Of All/htdocs/we");
    ok($paths->we_htmlurl, "/we"); # rooturl not set
    $paths->rooturl("/Root/URL");
    ok($paths->we_htmlurl, "/Root/URL/we"); # rooturl now set
    ok($paths->site_we_templatebase, "Root Of All/htdocs/we/my_test_project_we_templates");
}

__END__
