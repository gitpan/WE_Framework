# symlink or copy this file as WEsiteinfo.pm

package WEsiteinfo;

######################################################################
#
# Projectinfo
#
package WEprojectinfo;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(stagingextracgi));
$c = bless {}, __PACKAGE__;
$c->stagingextracgi(["bla.cgi"]);

######################################################################
#
# Paths
#
package WEsiteinfo::Paths;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(absoluteurl
			     rooturl rootdir cgiurl cgidir we_templatebase
			     site_templatebase we_htmlbase we_database photodir
			     pubhtmldir prototypedir));
$c = bless {}, __PACKAGE__;
$c->absoluteurl("http://www:80/~eserte/webeditor/wwwroot");
$c->rooturl("/~eserte/webeditor/wwwroot");
$c->pubhtmldir("$FindBin::RealBin/testhtml");

######################################################################
#
# Staging
#
package WEsiteinfo::Staging;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(transport user password host directory
			     cgidirectory tempdirectory temp2directory));
$c = bless {}, __PACKAGE__;

$c->transport("ftp");
$c->user("dummy");
$c->password("dummy");
$c->host("dad");
$c->directory("testproject_live");
$c->cgidirectory("testproject_live/cgi-bin");

######################################################################
#
# WEsiteinfo
#
package WEsiteinfo;
use base qw(Exporter Class::Accessor);
__PACKAGE__->mk_accessors(qw(project paths searchengine staging debug));
@EXPORT_OK = qw($c);
$c = bless {}, __PACKAGE__;

$c->paths($WEsiteinfo::Paths::c);
$c->staging($WEsiteinfo::Staging::c);
$c->project($WEprojectinfo::c);

1;


