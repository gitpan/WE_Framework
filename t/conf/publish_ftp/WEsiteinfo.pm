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
@stagingextracgi
	    );
}
use vars @EXPORT;
use strict;

$livetransport = 'ftp';
$liveuser = "dummy";
$livepassword = "dummy";
$livehost = "dad";
$livedirectory = "testproject_live";
$livecgidirectory = "testproject_live/cgi-bin";

$pubhtmldir = "$FindBin::RealBin/testhtml";

@stagingextracgi = ("bla.cgi");

1;
