# -*- perl -*-

#
# $Id: Date.pm,v 1.3 2003/01/16 14:29:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Util::Date;

=head1 NAME

WE::Util::Date - date-specific functions

=head1 SYNOPSIS

    use WE::Util::Date;
    print scalar localtime isodate2epoch("2001-12-12 12:23:00");

=head1 DESCRIPTION

This is a helper class for date functions.

=cut

use base qw(Exporter);

use strict;
use vars qw($VERSION @EXPORT @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

@EXPORT = qw(isodate2epoch epoch2isodate);
@EXPORT_OK = qw(short_readable_time);

use constant    T_FMT => "%04d-%02d-%02d %02d:%02d:%02d";

# some methods stolen from DateHelper.pm elsewhere

=head1 FUNCTIONS

=head2 isodate2epoch($isodate)

Return time in seconds since UNIX epoch for the given ISO 8601 string
(YYYY-MM-DD HH:MM:SS or YYYY-MM-DD). If Date::Manip is installed, more
ISO formats are allowed.

=cut

sub isodate2epoch {
    my $isodate = shift;
    require Time::Local;
    my($y,$m,$d,$H,$M,$S);
    if ($isodate =~ /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$/) {
	($y,$m,$d,$H,$M,$S) = ($1,$2,$3,$4,$5,$6);
    } elsif ($isodate =~ /^(\d{4})-(\d{2})-(\d{2})$/) { # crippled without time
	($y,$m,$d,$H,$M,$S) = ($1,$2,$3,0,0,0);
    } else {
	require Date::Manip;
        return Date::Manip::ParseDate($isodate);
    }
    Time::Local::timelocal($S,$M,$H,$d,$m-1,$y-1900);
}

=head2 epoch2isodate($time)

Return time as ISO 8601 date from given time in seconds since UNIX epoch.

=cut

sub epoch2isodate {
    my @l = @_ ? localtime $_[0] : localtime;
    sprintf(T_FMT,
	    $l[5]+1900, $l[4]+1, $l[3],
	    $l[2],      $l[1],   $l[0]);
}

=head2 short_readable_time($epoch)

Return the short time E<agrave> la "ls -al". (Not exported by default).

=cut

sub short_readable_time {
    my $epoch = shift;
    my @l = localtime $epoch;
    my @now = localtime;
    my $s = sprintf "%3s %2d ",
	[qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/]->[$l[4]],
	    $l[3];
    if ($l[5] == $now[5]) {
	$s .= sprintf "%02d:%02d", $l[2], $l[1];
    } else {
	$s .= sprintf "%5d", $l[5]+1900;
    }
    $s;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

