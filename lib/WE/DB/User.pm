# -*- perl -*-

#
# $Id: User.pm,v 1.13 2005/02/16 22:45:50 eserte Exp $
# Author: Olaf Mätzner
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::User;

use strict;
use vars qw($VERSION $ERROR);
$VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

use DB_File;
use Fcntl;

my $pwfile;
my $userdatabase;

use constant PW       => 0;
use constant GROUPS   => 1;
use constant FULLNAME => 2;
use constant USERDEF  => 3;

use constant ERROR_OK => 1;

sub new {
    my($class, $root, $file, %args) = @_;
    my $self = {};
    $pwfile = $file;
    bless $self, $class;

    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};

    my $flags;
    if ($args{-readonly}) {
	$flags = O_RDONLY;
    } elsif ($args{-writeonly}) {
	$flags = O_RDWR;
    } else {
	$flags = O_RDWR|O_CREAT;
    }

    if (!defined $args{-connect} || $args{-connect} ne 'never') {
	tie %{$self->{DB}}, "DB_File", "$file", $flags, 0644 or die("can't tie db (file $file): $!");
    }
    $self->{DBFile} = $file;
    $self;
}
sub disconnect {
    my $self = shift;
    eval {
	untie %{ $self->{DB} };
    };warn $@ if $@;
}
sub identify {
    my($self, $user, $password) = @_;
    my $ret = 0;
    if ( $self->user_exists($user) ) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my $cryptpw = $things[PW];
	my $crypt = _decrypt($password, $cryptpw);
	if ($crypt eq $cryptpw) { $ret=1 };
    }
    return $ret;
}
sub get_fullname {
    my($self, $user) = @_;
    if ( $self->user_exists($user) ) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my $fullname = $things[FULLNAME];
	if ($fullname) { return $fullname } else { return "" }
    } else {
	return 0;
    }
}
sub user_exists {
    my($self, $user) = @_;
    my $ret = 0;
    if ( $self->{DB}{$user} ) {$ret=1};
    return $ret;
}
sub add_user {
    my($self, $user, $password, $fullname, @userdef) = @_;
    if (!$fullname) {$fullname="new user"};
    my $ret = 0;
    if ( $self->user_exists($user) ) {
	$ERROR = "User $user exists already";
	return 0;
    };
    if ( $user=~/:/ ) {
	$ERROR = "Invalid character in user name";
	return 0;
    };
    $self->{DB}{$user} = join(":",_encrypt($password),"",$fullname,@userdef);
    return ERROR_OK;
}
sub update_user {
    my($self, $user, $password, $fullname,$groups,@userdef) = @_;
    if ( $self->user_exists($user) ) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my $pw;
	if ($password eq "") {
	    $password = $things[PW];
	} else {
	    $password = _encrypt($password);
	}
	if ($fullname eq "") {
	    $fullname = $things[FULLNAME];
	}
	if ($groups eq "") {
	    $groups = $things[GROUPS];
	}
	if (!@userdef) {
	    @userdef = @things[USERDEF..$#things];
	}
	$self->{DB}{$user} = join(":",$password,$groups,$fullname,@userdef);
    } else {
	$ERROR = "User $user does not exist";
	return 0;
    };
}
sub delete_user {
    my($self, $user) = @_;
    my $ret = 0;
    if ( !$self->{DB}{$user} ) {
	return 0;
    };
    delete $self->{DB}{$user};
    $ret=1;
    return $ret;
}
sub is_in_group {
    my($self, $user, $group) = @_;
    my $ret=0;
    if ( $self->user_exists($user) ) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	if ($things[GROUPS]) {
	    if ($things[GROUPS]=~/\b$group\b/) { $ret=1 };
	}
    }
    return $ret;
}
sub get_groups {
    my($self, $user) = @_;
    my @groups;
    if ($self->user_exists($user)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	@groups = split(/\#/, $things[GROUPS] );
    }
    return @groups;
}
sub get_user {
    my($self, $user) = @_;
    if ($self->user_exists($user)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my @groups = split(/\#/, $things[GROUPS] );
	return {
	    'groups' => \@groups,
	    'username' => $user,
	    'password' => $things[PW],
	    'fullname' => $things[FULLNAME],
	    'userdef'  => [@things[USERDEF..$#things]],
	    };
    } else {return 0}
}
sub add_group {
    my($self, $user, $group) = @_;
    my $ret=0;
    if ($group=~/\#/) {
	$ERROR = "Group name cannot contain # ";
	return 0;
    }
    if ($self->is_in_group($user,$group)) {
	return ERROR_OK; # $user already in $group
    }
    if ($self->user_exists($user)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my @groups;
	if ($things[GROUPS] ) { @groups = split(/\#/, $things[GROUPS] ); }
	push(@groups,$group);
	$self->{DB}{$user} = join(":", $things[PW], join("#",@groups), @things[FULLNAME, USERDEF..$#things]);
	$ret = ERROR_OK;
    }
    return $ret;
}
sub delete_group {
    my($self, $user, $delgroup) = @_;
    my $ret=0;
    if ( $self->user_exists($user) && $self->is_in_group($user,$delgroup)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	my @groups = $self->get_groups($user);
	my @newgroups;
	foreach my $g (@groups) {
	    if ($g ne $delgroup) { push(@newgroups,$g) }
	}
	$self->{DB}{$user} = join(":", $things[PW], join("#",@newgroups), @things[FULLNAME, USERDEF..$#things]);
	$ret=1;
    }
    return $ret;
}
sub get_users_of_group {
    my($self, $group) = @_;
    my @users;
    foreach my $usr (keys %{$self->{DB}}) {
	if ( $self->is_in_group($usr,$group) ) { push(@users,$usr); }
    }
    return @users;
}
sub get_all_users {
    my($self) = @_;
    my @allusers;
    foreach my $usr (keys %{$self->{DB}}) {
	push(@allusers, $usr);
    }
    return @allusers;
}
sub get_all_groups {
    my($self) = @_;
    my %groups;
    foreach my $usr (keys %{$self->{DB}}) {
	foreach my $grp ( $self->get_groups($usr) ) {
	    $groups{$grp}=1;
	}
    }
    $groups{'webusermanagers'}=1;
    return keys %groups;
}
sub set_user_field {
    my($self, $user, $field, $value) = @_;
    if ($self->user_exists($user)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	$things[USERDEF + $field] = $value;
	$self->{DB}{$user} = join(":", @things);
	1;
    }
}
sub get_user_field {
    my($self, $user, $field) = @_;
    if ($self->user_exists($user)) {
	my @things = split(/:/, $self->{DB}{$user}, -1);
	return $things[USERDEF + $field];
    }
}
sub _crypt {
    my($password, $salt) = @_;
    my $crypt;
    eval {
	local $SIG{__DIE__};
	$crypt = crypt($password, $salt);
    };
    if ($@) { $crypt = $password };
    $crypt;
}
sub _encrypt {
    my $password = shift;
    _crypt($password, &salt);
}
sub _decrypt {
    my($checkit, $old_password) = @_;
    _crypt($checkit, $old_password);
}
sub salt {
    my($salt) = '';               # initialization
    my($i, $rand) = (0, 0);
    my(@itoa64) = ( '.', '/', 0 .. 9, 'a' .. 'z', 'A' .. 'Z' ); # 0 .. 63

    # to64
    for ($i = 0; $i < 8; $i++) {
        srand(time + $rand + $$); 
        $rand = rand(25*29*17 + $rand);
        $salt .=  $itoa64[$rand & $#itoa64];
    }
    #warn "Salt is: $salt\n";

    return $salt;
}
# Deprecated! XXX
sub error {
    my($self, $errorcode) = @_;
    my @errtxt;
    $errtxt[0] = "not accepted";
    $errtxt[1] = "ok";
    $errtxt[2] = "invalid character";

    if ( $errtxt[$errorcode] ) {
	return $errtxt[$errorcode];
    } else {
	return "unknown error.";
    }
    return 0;
}

# Return 1 if this file is really a WE::DB::User file
sub check_data_format {
    my $self = shift;
    return 0 if exists $self->{DB}{__DBINFO__};
    my($firstuser) = each %{ $self->{DB} };
    if (!defined $firstuser) {
	return 1; # it's empty
    }
    my @f = split /:/, $self->{DB}{$firstuser};
    return @f >= 3; # at least password, groups, fullname
}

# XXX del:
#  sub delete_db {
#      my $self = shift;
#      unlink $self->{DBFile};
#  }

1;

__END__

=head1 NAME

WE::DB::User - Webeditor user database. 

=head1 SYNOPSIS

my $u = WE::DB::User->new(undef, $user_db_file);

$u->add_user(username,password,fullrealname)
 returns 1 if creation of user was successfull

$u->get_fullname(username)
 returns String with full reallife-name

$u->identify(username,entered_password)
 returns 1 if ok

$u->user_exists(username) 
 returns 1 if this user exists

$u->delete_user(username)
 returns 1 if successfull

$u->is_in_group(username,group)
 returns 1 if he is

$u->add_group(username,group)
 returns 1 if adding user to group was successfull

$u->delete_group(username,group)
 returns 1 if deleting user from group was successfull

$u->get_users_of_group(group)
 returns an Array of usernames belonging to this group

$u->get_all_users()
 returns an Array of all existing users (just the user names)

$u->get_all_groups()
 returns an Array of all existing groups (just the group names)

$u->get_user_field(user,fieldindex)
 return the value of the given user field

$u->set_user_field(user,fieldindex,value)
 returns 1 if successful

=head1 DESCRIPTION

Object for administration of webeditor-users. You can add, delete,
identify, modify users.

B<NOTE>: For new projects it is generally better to use the
L<WE::DB::ComplexUser> module instead.

=head1 AUTHOR

Olaf Mätzner - maetzner@onlineoffice.de

=head1 WARNING

The C<error> method is deprecated.

Some of the methods used to return 1 on success and any other number
(0 or 2) on failure. Now all methods return true on success and false
on failure. Additionally, some methods set the global C<$ERROR> package
variable to an error string.

=head1 SEE ALSO

L<WE::DB>, L<WE::DB::ComplexUser>.

=cut

