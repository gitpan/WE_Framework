# -*- perl -*-

#
# $Id: Logger.pm,v 1.5 2004/03/08 10:43:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
#

package WE_Frontend::Logger;

use strict;
use vars qw($logfile);
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub setup {
    my(%args) = @_;
    if (exists $args{-logfile}) {
	$logfile = delete $args{-logfile};
    }
    if (keys %args) {
	die "Unrecognized " . __PACKAGE__ . "::setup switches: " . join(", ", keys %args);
    }
}

sub user {
    my($we, $type) = @_;
    $type = "login" if !defined $type;
    my $user = (ref $we ? $we->CurrentUser : $we);
    my $date = scalar localtime time;
    my $host = $ENV{REMOTE_ADDR} || "unknwon";
    my $line = "$0: $type user " . $user . " at $date from $host\n";
 TRY: {
	last if !defined $logfile;
	last if !open(LOG, ">>$logfile");
	print LOG $line;
	close LOG;
	return;
    }

    print STDERR $line;
}

1;

__END__

=head1 NAME

WE_Frontend::Logger - logging facility

=head1 SYNOPSIS

    use WE_Frontend::Logger;
    WE_Frontend::Logger::setup(-logfile => ...);
    WE_Frontend::Logger::user($username, "login");

=head1 DESCRIPTION

This is a simple logging backend for the web.editor.

=over

=item setup(-logfile => $file)

Redirect logging to the named file.

=item user([ $username | $we_root_obj ], [ "login" | "logout" ])

Print a logger line to STDERR or a logfile (if setup was called). The
first argument is either a C<$username> string or a C<WE::Root>
object, from where the current username is extracted. The second
string is a free definable string like "login" or "logout".

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2002,2003 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO
