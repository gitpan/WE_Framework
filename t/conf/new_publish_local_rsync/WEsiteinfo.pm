# symlink or copy this file as WEsiteinfo.pm

package WEsiteinfo;

use WE_Frontend::Info;

######################################################################
#
# Projectinfo
#
package WEprojectinfo;
$c = bless {}, __PACKAGE__;
$c->stagingextracgi(["bla.cgi"]);

######################################################################
#
# Paths
#
package WEsiteinfo::Paths;
use base qw(Class::Accessor);
$c = bless {}, __PACKAGE__;
$c->pubhtmldir("$FindBin::RealBin/testhtml");
$c->cgidir("$FindBin::RealBin/testhtml/cgi-bin");

######################################################################
#
# Staging
#
package WEsiteinfo::Staging;
$c = bless {}, __PACKAGE__;

$c->transport("rsync");
$c->user(undef);
$c->host(undef);
$c->directory("/tmp/testproject_live-$<");
$c->cgidirectory("/tmp/testproject_live-$</cgi-bin");

######################################################################
#
# WEsiteinfo
#
package WEsiteinfo;
@EXPORT_OK = qw($c);
$c = bless {}, __PACKAGE__;

$c->paths($WEsiteinfo::Paths::c);
$c->staging($WEsiteinfo::Staging::c);
$c->project($WEprojectinfo::c);

1;
