package main;

package WEsiteinfo;
use base "Exporter";
BEGIN {
@EXPORT = qw(
$pubhtmldir
$livetransport
$liveuser
$livepassword
$livehost
$livedirectory
$livecgidirectory
$livestagingext
@stagingextracgi
	    );
}
use vars @EXPORT;
use strict;

$livetransport = 'ftp-md5sync';
$liveuser = "dummy";
$livepassword = "dummy";
$livehost = "dad";
$livedirectory = "md5sync-test";
$livecgidirectory = "md5sync-test/cgi-bin";
$livestagingext = {md5listcgi => "http://www/~eserte/cgi/get_md5_list.cgi",
		   topdirectory => "/home/dummy",
		  };

$pubhtmldir = "$FindBin::RealBin/testhtml";

@stagingextracgi = ("bla.cgi");

1;
