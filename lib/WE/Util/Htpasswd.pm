# -*- perl -*-

#
# $Id: Htpasswd.pm,v 1.8 2004/04/14 14:42:54 eserte Exp $
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

package WE::Util::Htpasswd;

use strict;
use vars qw($VERSION $HTPASSWD_EXE);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use File::Spec;
use WE::Util::Functions qw(is_in_path _save_pwd);

=head1 NAME

WE::Util::Htpasswd - create apache .htpasswd files from a user database

=head1 SYNOPSIS

    use WE::Util::Htpasswd;
    WE::Util::Htpasswd::create("/var/www/.htpasswd", $complex_user_db);

=head1 DESCRIPTION

Create apache C<.htpasswd> files from a WE_Framework user database.

=head2 FUNCTIONS

=over 4

=item create($dest_file, $user_db, %args);

Create the .htpasswd as C<$dest_file> from the (complex) user database
object C<$user_db>. Note that the user database should use the "none"
C<CryptMode> (that is, store plain text passwords).

=cut

sub create {
    my($dest_file, $user_db, %args) = @_;
    if ($user_db->CryptMode ne 'none') {
	die "CryptMode of the user database should be none";
    }
    unlink $dest_file;
    my $devnull = File::Spec->can("devnull") ? File::Spec->devnull : "/dev/null";
    #my $devnull = "/tmp/htpasswd-debug.log";
    my $htpasswd = htpasswd_exe();
    my @args = ('-c'); # first time: create htpasswd
    foreach my $uid ($user_db->get_all_users) {
	my $u = $user_db->get_user_object($uid);
	my $p = $u->Password;

	*OLDERR = *OLDERR;
	open(OLDERR, ">&STDERR");
	open(STDERR, ">" . $devnull);
	my @cmd = ($htpasswd, @args, "-b", $dest_file, $uid, $p);
	_save_pwd {
	    # htpasswd seems to use the current directory as temporary
	    # directory, so help here for a better location:
	    chdir "/tmp";
	    system @cmd;
	};
	close STDERR;
	open(STDERR, ">&OLDERR");

	if ($?/256!=0) {
	    die "htpasswd for file $dest_file and uid $uid returned " . ($?/256) . "\nCommand line was: @cmd\nPATH was $ENV{PATH}";
	}
	@args = ();
    }
    1;
}

=item add_user($dest_file, $user_object, %args);

Add the entry for a user to the C<.htpasswd> file C<$dest_file>. The
user object should be a C<WE::UserObj> object as created in
C<WE::DB::ComplexUser>.

=cut

sub add_user {
    my($dest_file, $u, %args) = @_;
    my $uid = $u->Username;
    my $p = $u->Password;
    my @args;
    if (!-e $dest_file) {
	push @args, "-c";
    }
    my $htpasswd = htpasswd_exe();
    my @cmd = ($htpasswd, @args, "-b", $dest_file, $uid, $p);
    system @cmd;
    if ($?/256!=0) {
	die "htpasswd for file $dest_file and uid $uid returned " . ($?/256) . "\nCommand line was: @cmd";
    }
    1;
}

=item invalid_chars

Return a string of invalid characters for htpasswd usernames. This is handy
for using in C<ComplexUser>:

    new WE::DB::ComplexUser(..., ...,
                            -crypt => "none",
                            -invalidchars => WE::Util::Htpasswd::invalid_chars(),
                            -invalidgroupchars => WE::Util::Htgroup::invalid_chars())

=cut

sub invalid_chars {
    ":";
}

sub htpasswd_exe {
 TRY: {
	if (!defined $HTPASSWD_EXE) {
	    $HTPASSWD_EXE = is_in_path("htpasswd");
	    last TRY if defined $HTPASSWD_EXE;
	    for my $exe (qw(/usr/local/bin/htpasswd
			    /usr/local/apache/bin/htpasswd)) {
		if (-x $exe) {
		    $HTPASSWD_EXE = $exe;
		    last TRY;
		}
	    }
	}
    }
    if (!defined $HTPASSWD_EXE) {
	die "Cannot find htpasswd binary in $ENV{PATH}";
    }
    $HTPASSWD_EXE;
}

1;

__END__

=back

=head1 TODO

Maybe optionally use Apache::Htpasswd from CPAN to create .htpasswd.
This would be handy if htpasswd is not available.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<htpasswd(1)>, L<WE::DB::ComplexUser>, L<WE::Util::Htgroup>, L<WE::Util::Htaccess>.

=cut

