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
__PACKAGE__->mk_accessors(qw(rooturl rootdir cgiurl cgidir we_templatebase
			     site_templatebase we_htmlbase we_database photodir
			     pubhtmldir prototypedir));
$c = bless {}, __PACKAGE__;
$c->pubhtmldir("$FindBin::RealBin/testhtml");
$c->cgidir("$FindBin::RealBin/testhtml/cgi-bin");

######################################################################
#
# Staging
#
package WEsiteinfo::Staging;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(transport user password host directory
			     cgidirectory tempdirectory temp2directory
			     stagingext));
$c = bless {}, __PACKAGE__;

$c->transport("ftp-md5sync");
$c->user("dummy");
$c->password("dummy");
$c->host("dad");
$c->directory("md5sync-test");
$c->cgidirectory("md5sync-test/cgi-bin");
$c->stagingext({md5listcgi => "http://www/~eserte/cgi/get_md5_list.cgi",
		topdirectory => "/home/dummy",
		#deleteold => 1,
		movetotrash => 1,
		trashdirectory => "/home/dummy/trash",

#		#               remote full path, remote ftp (short) path, local full path
#		mapping    => [["/home/dummy/md5sync-test/cgi-bin", $c->cgidirectory, $WEsiteinfo::Paths::c->cgidir],
#			       ["/home/dummy/md5sync-test", $c->directory, $WEsiteinfo::Paths::c->pubhtmldir],
#			      ],
	       });

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


