#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: 93_navigation_plugin.t,v 1.17 2004/10/06 09:12:56 eserte Exp $
# Author: Slaven Rezic
#

# Never ever open & save this with an whitespace-on-lineend-deleting editor!
# Don't use picture-mode with emacs on this file!

use strict;
use FindBin;
use vars qw($confdir);

use WE_Sample::Root;
use WE::Util::LangString qw(langstring);
BEGIN {
    $confdir = "$FindBin::RealBin/conf/new_publish_ftp";
}
use lib $confdir; # for WEsiteinfo.pm
use WE_Frontend::Main2;
use WEsiteinfo qw($c);

BEGIN {
    if (!eval q{
	use Test;
	use Template 2.09; # because of modern "DEBUG" directive
	1;
    }) {
	print "# tests only work with installed Test and Template 2.09 modules\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

# depends on: recent runs of 90_sample.t and 92_support.t
# XXX check automatically for this dependency (?)

BEGIN { plan tests => 22 }

my $testdir = "$FindBin::RealBin/test";
my $r = new WE_Sample::Root -rootdir => $testdir,
                            -connect => 1;
my $objdb = $r->{ObjDB};
my $objid = $objdb->name_to_objid("named_object");

#goto TEST6;

my $text1 = <<EOF;
[% USE n = Navigation %]

My Id: [% n.self.o.Id %]
Access from named object: [% n.object_by_name("named_object").o.Id %]
Again: [% n.get_object(name = "named_object").o.Id %]
Parent Id: [% n.parent.o.Id %]
Level: [% n.level %]

Path: [% SET first = 1 -%]
[% FOR p = n.ancestors -%]
  [%- IF first %][% first = 0 %][% ELSE %] | [% END %][% p.o.Id -%]
[% END -%]
 | [% n.self.o.Id %] (self)

Path without root: [% SET first = 1 -%]
[% FOR p = n.ancestors(fromlevel = 1) -%]
  [%- IF first %][% first = 0 %][% ELSE %] | [% END %][% p.o.Id -%]
[% END -%]

Path without root and toplevel: [% SET first = 1 -%]
[% FOR p = n.ancestors(fromlevel = 2) -%]
  [%- IF first %][% first = 0 %][% ELSE %] | [% END %][% p.o.Id -%]
[% END -%]

Path without last: [% SET first = 1 -%]
[% FOR p = n.ancestors(tolevel = 1) -%]
  [%- IF first %][% first = 0 %][% ELSE %] | [% END %][% p.o.Id -%]
[% END -%]

Path without first and last: [% SET first = 1 -%]
[% FOR p = n.ancestors(fromlevel = 1, tolevel = 1) -%]
  [%- IF first %][% first = 0 %][% ELSE %] | [% END %][% p.o.Id -%]
[% END %]

Siblings:
---------
[% FOR p = n.siblings -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_self(p) %] *[% END %]
  [%- SET p2 = n.get_object(objid = p.o.Id) %]

  [%- p2.o.Id %] (by get_object)
[% END %]

Siblings in level 1:
--------------------
[% FOR p = n.siblings(level = 1) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %] [% IF n.is_ancestor(p) %] (an ancestor) [% END %]
[% END %]

Siblings in level 2:
--------------------
[% FOR p = n.siblings(level = 2) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %] [% IF n.is_ancestor(p) %] (an ancestor) [% END %]
[% END %]

Children:
---------
[% FOR p = n.children -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %]
[% END %]

Children of Object 4:
---------------------
[% FOR p = n.children(objid = 4) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %]
[% END %]

EOF

my $oktext1 = <<'EOF';


My Id: 38
Access from named object: 38
Again: 38
Parent Id: 5
Level: 3

Path: 0 | 4 | 5 | 38 (self)

Path without root: 4 | 5
Path without root and toplevel: 5
Path without last: 0 | 4
Path without first and last: 4

Siblings:
---------
11 New title for doc4
11 (by get_object)
12 Move test 1
12 (by get_object)
13 Move test 2
13 (by get_object)
14 Move test 3
14 (by get_object)
15 Move test 4
15 (by get_object)
16 Move test 5
16 (by get_object)
38 90_sample *
38 (by get_object)


Siblings in level 1:
--------------------
1 Titel Menü 1 
2 Titel Menü 2 
4 Titel Menü 4  (an ancestor) 
6 Titel Menü 6 
51 Support 1 
55 Support 2 


Siblings in level 2:
--------------------
10 Ein Titel 
5 Titel Menü 5  (an ancestor) 
39 90_sample 
40 A document in folder three 
41 Ein Folder in 3 


Children:
---------


Children of Object 4:
---------------------
10 Ein Titel
5 Titel Menü 5
39 90_sample
40 A document in folder three
41 Ein Folder in 3


EOF

my $t1 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
my $output1;
my $ret1 = $t1->process(\$text1, {objdb => $objdb,
				  objid => $objid,
				  langstring => \&langstring}, \$output1);
ok($ret1, 1, $t1->error);
ok($output1, $oktext1);
if ($output1 ne $oktext1) {
    show_diff($oktext1, $output1);
}

######################################################################
# Test WE_Navigation

my $text2 = <<EOF;
[%- USE n = WE_Navigation -%]
My Id: [% n.self.o.Id %]
My properties:
    Default language title: [% n.self.lang_title %]
    German language title:  [% n.self.lang_title("de") %]
    English language title: [% n.self.lang_title("en") %]
    Language short title:   [% n.self.lang_short_title %]
    Relative URL:           [% n.self.relurl %]
    Half-absolute URL:      [% n.self.halfabsurl %]
    Absolute URL:           [% n.self.absurl %]
    Include in navigation:  [% IF n.self.include_in_navigation %]yes[% ELSE %]no[% END %]
EOF

my $oktext2 = <<'EOF';
My Id: 40
My properties:
    Default language title: A document in folder three
    German language title:  Ein Dok in Verzeichnis 3
    English language title: A document in folder three
    Language short title:   A document in folder three
    Relative URL:           40.html
    Half-absolute URL:      /~eserte/webeditor/wwwroot/html/en/40.html
    Absolute URL:           http://www:80/~eserte/webeditor/wwwroot/html/en/40.html
    Include in navigation:  yes
EOF

my $objid2 = $objdb->name_to_objid("test for 93_navigation_plugin");
my $t2 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
my $output2;
my $ret2 = $t2->process(\$text2, {objdb => $objdb,
				  objid => $objid2,
				  config => $c}, \$output2);
ok($ret2, 1, $t2->error);
ok($output2, $oktext2);
if ($output2 ne $oktext2) {
    show_diff($oktext2, $output2);
}

######################################################################
# Test WE_Navigation: root object

my $text3 = <<EOF;
[%- USE n = WE_Navigation -%]
My Id: [% n.self.o.Id %]
My properties:
    Default language title: [% n.self.lang_title %]
    German language title:  [% n.self.lang_title("de") %]
    English language title: [% n.self.lang_title("en") %]
    Language short title:   [% n.self.lang_short_title %]
    Relative URL:           [% n.self.relurl %]
    Half-absolute URL:      [% n.self.halfabsurl %]
    Absolute URL:           [% n.self.absurl %]
    Include in navigation:  [% IF n.self.include_in_navigation %]yes[% ELSE %]no[% END %]
EOF

my $oktext3 = <<'EOF';
My Id: 0
My properties:
    Default language title: Root of the site
    German language title:  Wurzel der Website
    English language title: Root of the site
    Language short title:   Root of the site
    Relative URL:           index.html
    Half-absolute URL:      /~eserte/webeditor/wwwroot/html/en/index.html
    Absolute URL:           http://www:80/~eserte/webeditor/wwwroot/html/en/index.html
    Include in navigation:  no
EOF

# Still the same, but maybe I should use IndexDoc or similar...
my $oktext3_new = <<'EOF';
My Id: 0
My properties:
    Default language title: Root of the site
    German language title:  Wurzel der Website
    English language title: Root of the site
    Language short title:   Root of the site
    Relative URL:           index.html
    Half-absolute URL:      /~eserte/webeditor/wwwroot/html/en/index.html
    Absolute URL:           http://www:80/~eserte/webeditor/wwwroot/html/en/index.html
    Include in navigation:  no
EOF

my $objid3 = $objdb->root_object->Id;
my $t3 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});
{
    local $WE_Frontend::Plugin::WE_Navigation::Object::DONT_USE_INDEXDOC = 1;
    local $WE_Frontend::Plugin::WE_Navigation::Object::IGNORE_NAME_DB = 1;
    my $output3;
    my $ret3 = $t3->process(\$text3, {objdb => $objdb,
				      objid => $objid3,
				      config => $c}, \$output3);
    ok($ret3, 1, $t3->error);
    ok($output3, $oktext3);
    if ($output3 ne $oktext3) {
	show_diff($oktext3, $output3);
    }
}

{
    my $output3;
    my $ret3 = $t3->process(\$text3, {objdb => $objdb,
				      objid => $objid3,
				      config => $c}, \$output3);
    ok($ret3, 1, $t3->error);
    ok($output3, $oktext3_new);
    if ($output3 ne $oktext3_new) {
	show_diff($oktext3_new, $output3);
    }
}


######################################################################
# Test for navigation, siblings level above

TEST4:
$objid = $objdb->name_to_objid("named_object")
    or die "Can't get objid for `named_object'";

my $text4 = <<EOF;
[%- USE n = Navigation(objid = $objid) -%]

My id is [% n.self.o.Id %].

My siblings:
------------
[% FOR p = n.siblings -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_ancestor(p) %] (an ancestor)[% END %]
[% END %]

Siblings in level above (my aunts and uncles):
----------------------------------------------
[% FOR p = n.siblings(level = -1) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_ancestor(p) %] (an ancestor)[% END %]
[% END %]

Siblings two levels above (my grandaunts and granduncles):
----------------------------------------------------------
[% FOR p = n.siblings(level = -2) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_ancestor(p) %] (an ancestor)[% END %]
[% END %]

Siblings three levels above (only the root):
----------------------------------------------------------
[% FOR p = n.siblings(level = -3) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_ancestor(p) %] (an ancestor)[% END %]
[% END %]
EOF

my $oktext4 = <<EOF;

My id is 38.

My siblings:
------------
11 New title for doc4
12 Move test 1
13 Move test 2
14 Move test 3
15 Move test 4
16 Move test 5
38 90_sample


Siblings in level above (my aunts and uncles):
----------------------------------------------
10 Ein Titel
5 Titel Menü 5 (an ancestor)
39 90_sample
40 A document in folder three
41 Ein Folder in 3


Siblings two levels above (my grandaunts and granduncles):
----------------------------------------------------------
1 Titel Menü 1
2 Titel Menü 2
4 Titel Menü 4 (an ancestor)
6 Titel Menü 6
51 Support 1
55 Support 2


Siblings three levels above (only the root):
----------------------------------------------------------
0 Root of the site (an ancestor)

EOF

my $t4 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			EVAL_PERL => 1});
my $output4;
my $ret4 = $t4->process(\$text4, {objdb => $objdb,
				  config => $c,
				  langstring => \&langstring}, \$output4);
ok($ret4, 1, $t4->error);
ok($output4, $oktext4);
if ($output4 ne $oktext4) {
    show_diff($oktext4, $output4);
}


# force error
my $text5 = <<EOF;
[%- USE n = Navigation(objid = $objid) -%]
[% FOR p = n.siblings(level = -4) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_ancestor(p) %] (an ancestor)[% END %]
[% END %]
EOF
my $t5 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			EVAL_PERL => 1});
$@ = "";
my $output5;
my $ret5 = $t5->process(\$text5, {objdb => $objdb,
				  config => $c,
				  langstring => \&langstring}, \$output5);
ok(!$ret5);
ok($@ =~ /Level above root object/);

######################################################################
# Test WE_Navigation: sequence and obj_proxy

TEST6:
{
    package WE_sample::Root::Plugin::MyNavigation;
    use base qw(WE_Frontend::Plugin::WE_Navigation);
    sub Object { "WE_sample::Root::Plugin::MyNavigation::Object" }

    package WE_sample::Root::Plugin::MyNavigation::Object;
    use base qw(WE_Frontend::Plugin::WE_Navigation::Object);
    sub obj_proxy {
	my($self, $caller) = @_;
	if ($caller eq 'title') {
	    # do not change the titles
	    return $self;
	}
	my $objdb = $self->Navigation->{ObjDB};
	if ($self->o->is_sequence) {
	    my @children = $objdb->children_ids($self->o->Id);
	    if (@children) {
		my $class = ref $self;
		my $child = $class->new($objdb->get_object($children[0]),
					$self->Navigation);
		return $child;
	    }
	}
	$self;
    }
    $INC{"WE_sample/Root/Plugin/MyNavigation.pm"} = __FILE__; # cheat
}

my $text6 = <<EOF;
[%- USE n = MyNavigation -%]
My properties:
    Default language title: [% n.self.lang_title %]
    German language title:  [% n.self.lang_title("de") %]
    English language title: [% n.self.lang_title("en") %]
    Language short title:   [% n.self.lang_short_title %]
    Relative URL:           [% n.self.relurl %]
    Half-absolute URL:      [% n.self.halfabsurl %]
    Absolute URL:           [% n.self.absurl %]
    Include in navigation:  [% IF n.self.include_in_navigation %]yes[% ELSE %]no[% END %]
EOF

my $oktext6 = <<'EOF';
My properties:
    Default language title: Eine Sequenz
    German language title:  Eine Sequenz
    English language title: Eine Sequenz
    Language short title:   Eine Sequenz
    Relative URL:           46.html
    Half-absolute URL:      /~eserte/webeditor/wwwroot/html/en/46.html
    Absolute URL:           http://www:80/~eserte/webeditor/wwwroot/html/en/46.html
    Include in navigation:  no
EOF

my $objid6 = $objdb->name_to_objid("sequence-test");
my $t6 = Template->new({PLUGIN_BASE => "WE_sample::Root::Plugin"});
my $output6;
my $ret6 = $t6->process(\$text6, {objdb => $objdb,
				  objid => $objid6,
				  config => $c}, \$output6);
ok($ret6, 1, $t6->error);
ok($output6, $oktext6);
if ($output6 ne $oktext6) {
    show_diff($oktext6, $output6);
}

######################################################################
# Test restrict and sort

my $text7 = <<'EOF';
[% USE n = Navigation %]

Folders:
[% FOR p = n.ancestors(restrict = "is_folder") -%]
  [% p.o.Id%]
[% END -%]

First folder: [% n.ancestors(restrict = "is_folder").first.o.Id %]
Last folder:  [% n.ancestors(restrict = "is_folder").last.o.Id %]

Documents:
[% FOR p = n.ancestors(restrict = "is_doc") -%]
  [% p.o.Id%]
[% END -%]

Objects with ID lesser than 5:
[% FOR p = n.ancestors(restrict = "my_restrict") -%]
  [% p.o.Id%]
[% END -%]

Folder siblings:
[% FOR p = n.siblings(restrict = "is_folder") -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_self(p) %] *[% END %]
[% END %]

Document siblings:
[% FOR p = n.siblings(restrict = "is_doc") -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_self(p) %] *[% END %]
[% END %]

Folder children of object 4:
[% FOR p = n.children(restrict = "is_folder", objid = 4) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %]
[% END %]

Document children of object 4:
[% FOR p = n.children(restrict = "is_doc", objid = 4) -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %]
[% END %]

Sort siblings by title:
[% FOR p = n.siblings(sort = "my_sort") -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_self(p) %] *[% END %]
[% END %]

Sort document children of object 4 by title:
[% FOR p = n.children(sort = "my_sort", objid = 4, restrict => "is_doc") -%]
  [%- p.o.Id %] [% langstring(p.o.Title) %][% IF n.is_self(p) %] *[% END %]
[% END %]

EOF

my $oktext7 = <<'EOF';


Folders:
  0
  4
  5

First folder: 0
Last folder:  5

Documents:

Objects with ID lesser than 5:
  0
  4

Folder siblings:


Document siblings:
11 New title for doc4
12 Move test 1
13 Move test 2
14 Move test 3
15 Move test 4
16 Move test 5
38 90_sample *


Folder children of object 4:
5 Titel Menü 5
41 Ein Folder in 3


Document children of object 4:
10 Ein Titel
39 90_sample
40 A document in folder three


Sort siblings by title:
38 90_sample *
12 Move test 1
13 Move test 2
14 Move test 3
15 Move test 4
16 Move test 5
11 New title for doc4


Sort document children of object 4 by title:
39 90_sample
40 A document in folder three
10 Ein Titel


EOF

{
    package WE_Frontend::Plugin::Navigation;
    sub my_sort {
	my($self, $a, $b) = @_;
	main::langstring($a->o->Title) cmp main::langstring($b->o->Title);
    }
}

{
    package WE_Frontend::Plugin::Navigation::Object;
    sub my_restrict {
	my $o = shift;
	$o->o->Id < 5;
    }
}

my $t7 = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			EVAL_PERL => 1});
my $output7;
my $ret7 = $t7->process(\$text7, {objdb => $objdb,
				  objid => $objid,
				  langstring => \&langstring}, \$output7);
ok($ret7, 1, $t7->error);
ok($output7, $oktext7);
if ($output7 ne $oktext7) {
    show_diff($oktext7, $output7);
}

######################################################################
# ancestors
{
    my $text = <<'EOF';
[%- USE n = Navigation -%]
[% FOR p = n.ancestors -%][% p.o.Id%] [% END %]|
[% FOR p = n.ancestors(fromlevel=1, tolevel=2) -%][% p.o.Id%] [% END %]|
[% FOR p = n.ancestors(fromlevel=1, tolevel=1) -%][% p.o.Id%] [% END %]|
EOF

    my $oktext = <<'EOF';
0 4 5 |
4 5 |
4 |
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			   EVAL_PERL => 1});
    my $output;
    my $ret = $t->process(\$text, {objdb => $objdb,
				   objid => $objid,
				   langstring => \&langstring}, \$output);
    ok($ret, 1, $t->error);
    ok($output, $oktext);
    if ($output ne $oktext) {
	 show_diff($oktext, $output);
     }
}

######################################################################
# one children, equals
{
    my $text = <<EOF;
[% USE n = WE_Navigation -%]
[% SET o = n.object_by_name("only_one_child") -%]
Object title: [% o.o.Title %]
[% SET c = n.children(name = "only_one_child") -%]
Number of children: [% c.size %]
First child: [% c.0.o.Title %]
[% FOR i = c -%]
* [% i.o.Title %]
[% END -%]
Again
[% FOR i = n.children(name = "only_one_child") -%]
* [% i.o.Title %]
[% END -%]
[% IF n.equals(c.0, name = "child_of_only_one_child") -%]
Equals!
[% END -%]
EOF

    my $oktext = <<EOF;
Object title: Support 1/1
Number of children: 1
First child: Support 1/1/1
* Support 1/1/1
Again
* Support 1/1/1
Equals!
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			   DEBUG => 'undef',
			   EVAL_PERL => 1});
    my $output;
    my $ret = $t->process(\$text, {objdb => $objdb,
				   langstring => \&langstring}, \$output);
    ok($ret, 1, $t->error);
    ok($output, $oktext);
    if ($output ne $oktext) {
	show_diff($oktext, $output);
    }
}

######################################################################
# diagnostics
{
    my $text = <<EOF;
[% USE n = WE_Navigation -%]
[% SET o = n.non_existing_method("only_one_child") -%]
EOF

    my $oktext = <<EOF;
EOF

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin",
			   DEBUG => 'undef',
			   EVAL_PERL => 1});
    my $output;
    my $ret = $t->process(\$text, {objdb => $objdb,
				   langstring => \&langstring}, \$output);
    ok($ret, undef);
    ok($t->error, qr/undef error - non_existing_method is undefined/);
}

######################################################################
sub show_diff {
    my($s1,$s2) = @_;
    my $tmpdir = tmpdir();
    my $base   = "$tmpdir/test.$$";

    open(S1, ">$base.1") or die $!;
    print S1 $s1;
    close S1;
    open(S2, ">$base.2") or die $!;
    print S2 $s2;
    close S2;

    open(DIFF, "diff -u $base.1 $base.2 |");
    while(<DIFF>) {
	print "# $_";
    }
    close DIFF;

    unlink "$base.1";
    unlink "$base.2";
}

# REPO BEGIN
# REPO NAME tmpdir /home/e/eserte/src/repository 
# REPO MD5 c41d886135d054ba05e1b9eb0c157644

=head2 tmpdir()

=for category File

Return temporary directory for this system. This is a small
replacement for File::Spec::tmpdir.

=cut

sub tmpdir {
    foreach my $d ($ENV{TMPDIR}, $ENV{TEMP},
		   "/tmp", "/var/tmp", "/usr/tmp", "/temp") {
	next if !defined $d;
	next if !-d $d || !-w $d;
	return $d;
    }
    undef;
}
# REPO END

__END__
