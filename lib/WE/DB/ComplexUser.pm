# -*- perl -*-

#
# $Id: ComplexUser.pm,v 2.20 2005/02/16 22:45:49 eserte Exp $
# Author: Olaf Mätzner, Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::ComplexUser;

use base qw(WE::DB::Base WE::DB::User Class::Accessor);
__PACKAGE__->mk_accessors(qw(DB CryptMode InvalidChars InvalidGroupChars
			     DBFile DBTieArgs ErrorType ErrorMsg));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 2.20 $ =~ /(\d+)\.(\d+)/);

use MLDBM;
use Fcntl;

{
    package WE::EntityObj;
    use base qw(Class::Accessor);
    __PACKAGE__->mk_accessors(qw(Id));
    sub new  {
	my $self = bless {}, shift;
	my %args = @_;
	while(my($k,$v) = each %args) {
	    $self->$k($v);
	}
	$self;
    }
}

{
    package WE::UserObj;
    use base qw(WE::EntityObj);
    # AuthType should be "" or "userdb" for using local passwords
    __PACKAGE__->mk_accessors
	(qw(Username Password Realname Groups Roles Email
	    Homedirectory Shell Language AuthType));
    sub name { shift->Username }
}

sub UserObjClass { "WE::UserObj" }

{
    package WE::GroupObj;
    use base qw(WE::EntityObj);
    __PACKAGE__->mk_accessors
	(qw(Groupname Description));
    sub name { shift->Groupname }
}

sub GroupObjClass { "WE::GroupObj" }

{
    # this will be written to the database and should not be used otherwise
    package WE::DB::ComplexUser::DBInfo;
    use base qw(Class::Accessor);
    __PACKAGE__->mk_accessors
	(qw(CryptMode InvalidChars InvalidGroupChars));
    sub new { bless {}, $_[0] }
}

use constant ERROR_NOT_ACCEPTED => 0;
use constant ERROR_OK           => 1;
use constant ERROR_INVALID_CHAR => 2;
use constant ERROR_GROUP_EXISTS => 3;
use constant ERROR_USER_EXISTS  => 4;

use constant NEXT_ID_KEY => "__NEXT_ID__";
use constant GROUPS_KEY  => "__GROUPS__";

use constant ERROR_TYPE_DIE    => 0;
use constant ERROR_TYPE_RETURN => 1;

sub new {
    my($class, $root, $file, %args) = @_;

    $args{-db}         = "DB_File" unless defined $args{-db};
    $args{-serializer} = "Data::Dumper" unless defined $args{-serializer};
    $args{-locking}    = 0 unless defined $args{-locking};
    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};
    $args{-connect}    = 1 unless defined $args{-connect};

    my $self = {};
    bless $self, $class;

    my @tie_args;
    if ($args{-readonly}) {
	push @tie_args, O_RDONLY;
    } elsif ($args{-writeonly}) {
	push @tie_args, O_RDWR;
    } else {
	push @tie_args, O_RDWR|O_CREAT;
    }

    push @tie_args, $args{-db} eq 'Tie::TextDir' ? 0770 : 0660;

    if ($args{-db} eq 'DB_File') {
	require DB_File;
	push @tie_args, $DB_File::DB_HASH;
	if ($args{-locking}) {
	    $MLDBM::UseDB = 'DB_File::Lock';
	    push @tie_args, $args{-readonly} ? "read" : "write";
	} else {
	    $MLDBM::UseDB = 'DB_File';
	}
    } else {
	$MLDBM::UseDB = $args{-db};
    }

    $MLDBM::Serializer = $args{-serializer};

    $self->DBFile($file);
    $self->DBTieArgs(\@tie_args);

    $self->Root($root);
    $self->Connected(0);
    $self->ErrorType(ERROR_TYPE_DIE);

    $self->connect_if_necessary(sub {
        # read database information
        my $db_info = $self->DB->{__DBINFO__};
    	if (!defined $db_info) {
    	    $db_info = $self->DB->{__DBINFO__} = new WE::DB::ComplexUser::DBInfo;
    	}
    	# sync members with DBINFO
    	if ($db_info) {
    	    $self->CryptMode($db_info->CryptMode);
    	    $self->InvalidChars($db_info->InvalidChars);
    	    $self->InvalidGroupChars($db_info->InvalidGroupChars);
    	}
    	# set %args
    	if (!$self->CryptMode) {
    	    $self->CryptMode(defined $args{-crypt} ? $args{-crypt} : 'crypt');
    	    $db_info->CryptMode($self->CryptMode) if $db_info;
    	}
    	if (!$self->InvalidChars) {
    	    $self->InvalidChars(defined $args{-invalidchars} ? $args{-invalidchars} : '');
    	    $db_info->InvalidChars($self->InvalidChars) if $db_info;
    	}
    	if (!$self->InvalidGroupChars) {
    	    $self->InvalidGroupChars(defined $args{-invalidgroupchars} ? $args{-invalidgroupchars} : '');
    	    $db_info->InvalidGroupChars($self->InvalidGroupChars) if $db_info;
    	}
    	# write back database information
    	if (!$args{-readonly}) {
    	    $self->DB->{__DBINFO__} = $db_info;
    	}
    });

    if ($args{-connect} && $args{-connect} ne 'never') {
	$self->connect;
    }

    $self;
}

sub connect {
    my $self = shift;
    tie %{ $self->{DB} }, 'MLDBM', $self->DBFile, @{$self->DBTieArgs}
	or require Carp, Carp::confess("Can't tie MLDBM database @{[$self->DBFile]} with args <@{$self->DBTieArgs}>, db <$MLDBM::UseDB> and serializer <$MLDBM::Serializer>: $!");
    $self->Connected(1);
}

sub _next_id {
    my($self) = @_;
    $self->connect_if_necessary
	(sub {
	     my $id = $self->{DB}->{NEXT_ID_KEY()} || 0;
	     $self->{DB}->{NEXT_ID_KEY()}++;
	     $id;
	 });
}

sub identify {
    my($self, $user, $password) = @_;
    $self->identify_object($user, $password) ? ERROR_OK : ERROR_NOT_ACCEPTED;
}

sub identify_object {
    my($self, $user, $password) = @_;
    my $u;
    $self->connect_if_necessary(sub {
    	if ($self->user_exists($user)) {
	    $u = $self->get_user_object($user);
	    my $authtype = $u->AuthType;
	TRY_AUTH: {
		if ($authtype && $authtype ne "userdb") {
		    my $method = "identify_${authtype}";
		    my $code = qq{use mixin 'WE::DB::ComplexUser::Auth${authtype}'; \$self->can('${method}');} ;
		    if (!eval $code) {
			warn "$code: $@";
			last TRY_AUTH;
		    }
		    my $ret = $self->$method($u, $password);
		    if ($ret != ERROR_OK) {
			undef $u;
		    }
		    last TRY_AUTH;
		}

		my $cryptpw = $self->DB->{$user}->Password;
		my $crypt = $self->_decrypt($password, $cryptpw);
		if ($crypt ne $cryptpw) {
		    undef $u;
		};
	    }
    	}
    });
    $u;
}

sub get_fullname {
    my($self, $user) = @_;
    my $ret = 0;
    $self->connect_if_necessary(sub {
        if ( $self->user_exists($user) ) {
	    my $fullname = $self->DB->{$user}->Realname;
	    if (defined $fullname) { $ret = $fullname } else { $ret = "" }
	}
    });
    return $ret;
}

sub user_exists {
    my($self, $user) = @_;
    $self->connect_if_necessary(sub {
        exists $self->DB->{$user} ? 1 : 0;
    });
}

sub add_user {
    my($self, $user, $password, $fullname) = @_;
    $self->connect_if_necessary(sub {
    	if ( $self->user_exists($user) ) {
	    $self->ErrorMsg("User <$user> exists already");
    	    return ERROR_USER_EXISTS;
    	}
    	if ( $user =~ /^_/) {
	    my $msg = "Usernames starting with `_' are not allowed";
	    if ($self->ErrorType eq ERROR_TYPE_RETURN) {
		$self->ErrorMsg($msg);
		return ERROR_INVALID_CHAR;
	    } else {
		die $msg;
	    }
    	}
    	if ( $self->InvalidChars ne '' ) {
    	    my $rcrx = "[" . quotemeta($self->InvalidChars) . "]";
    	    if ($user =~ /$rcrx/) {
		my $msg = "Invalid characters (some of @{[ $self->InvalidChars ]} in user name";
		if ($self->ErrorType eq ERROR_TYPE_RETURN) {
		    $self->ErrorMsg($msg);
		    return ERROR_INVALID_CHAR;
		} else {
		    die $msg;
		}
    	    }
    	}
    	my $o = $self->UserObjClass->new;
    	$o->Username($user);
    	$o->Password($self->_encrypt($password));
    	if (!$fullname) {$fullname="new user"};
    	$o->Realname($fullname);
    	$self->DB->{$user} = $o;
	ERROR_OK;
    });
}

# This is inefficient, but safe:
sub add_user_object {
    my($self, $user_object) = @_;
    my $user = $user_object->Username;
    if (!defined $user) {
	die "Username is empty in user object";
    }
    my $password = $user_object->Password;
    my $ret = $self->add_user($user, $password, undef);
    return $ret if $ret != ERROR_OK;
    my $id = $self->_next_id;
    $user_object->Id($id);
    my $new_user_object = $self->get_user_object($user);
    $user_object->Password($new_user_object->Password); # the password is maybe encrypted now
    $self->set_user_object($user, $user_object);
    ERROR_OK;
}

sub update_user {
    my($self, $user, $password, $fullname, $groups) = @_;
    $self->connect_if_necessary(sub {
    	if ( !$self->user_exists($user) ) {
    	    return 0;
    	}
    	my $o = $self->DB->{$user};
    	if (defined $password) {
    	    $password = $self->_encrypt($password);
    	    $o->Password($password);
    	}
    	if (defined $fullname) {
    	    $o->Realname($fullname);
    	}
    	if (defined $groups) {
    	    $o->Groups($groups);
    	}
    	$self->DB->{$user} = $o;
    	1;
    });
}

sub delete_user {
    my($self, $user) = @_;
    $self->connect_if_necessary(sub {
    	my $ret = 0;
    	if (!$self->user_exists($user)) {
    	    return 0;
    	}
    	delete $self->DB->{$user};
    	1;
    });
}

sub is_in_group {
    my($self, $user, $group) = @_;
    $self->connect_if_necessary(sub {
    	if ( $self->user_exists($user) ) {
    	    my $o = $self->DB->{$user};
    	    return 0 if !defined $o->{Groups};
    	    if (!ref $o->{Groups} eq 'ARRAY') {
    		return $o->{Groups} eq $group;
    	    } else {
    		foreach (@{ $o->{Groups} }) {
    		    return 1 if ($_ eq $group);
    		}
    	    }
    	}
    	0;
    });
}

sub get_groups {
    my($self, $user) = @_;
    $self->connect_if_necessary(sub {
    	my @groups;
    	if ($self->user_exists($user)) {
    	    my $o = $self->DB->{$user};
    	    if (ref $o->{Groups} eq 'ARRAY') {
    		return @{ $o->{Groups} };
    	    } else {
    		return (defined $o->{Groups} ? $o->{Groups} : ());
    	    }
    	}
    	();
    });
}

sub get_user {
    my($self, $user) = @_;
    $self->connect_if_necessary(sub {
    	if ($self->user_exists($user)) {
    	    my $o = $self->DB->{$user};
    	    my @groups = $self->get_groups($user);
    	    my $ret = +{
    			'groups' => \@groups,
    			'username' => $user,
    			'password' => $o->Password,
    			'fullname' => $o->Realname,
			'email'    => $o->Email,
    		       };
    	    foreach my $key (keys %$o) {
    		next if $key =~ /^(Username|Password|Realname|Groups|Email)$/;
    		$ret->{$key} = $o->{$key}
    		    unless exists $ret->{$key}; # do not override key entries
    	    }
    	    return $ret;
    	} else {return 0}
    });
}

sub get_user_object {
    my($self, $user) = @_;
    $self->connect_if_necessary(sub {
    	my $o = $self->DB->{$user};
    	$o;
    });
}

sub set_user_object {
    my $self = shift;
    my($user, $o);
    if (@_ == 1) {
	$o = $_[0];
	$user = $o->Username;
    } else {
	($user, $o) = @_;
    }
    $self->connect_if_necessary(sub {
    	die "\$o is not an WE::UserObj object"
    	    if !UNIVERSAL::isa($o, $self->UserObjClass);
    	die "Not allowed: Username in \$o was changed to @{[ $o->Username ]}, but must be $user"
    	    if $user ne $o->Username;
    	$self->DB->{$user} = $o;
    	$o;
    });
}

sub add_group {
    my($self, $user, $group) = @_;

    if ( $self->InvalidGroupChars ne '' ) {
	my $rcrx = "[" . quotemeta($self->InvalidGroupChars) . "]";
	if ($group =~ /$rcrx/) {
	    my $msg = "Invalid characters (some of @{[ $self->InvalidGroupChars ]} in group name";
	    if ($self->ErrorType eq ERROR_TYPE_RETURN) {
		$self->ErrorMsg($msg);
		return ERROR_INVALID_CHAR;
	    } else {
		die $msg;
	    }
	}
    }

    $self->connect_if_necessary(sub {
    	my $ret=0;
    	if ($self->is_in_group($user,$group)) { return 0;}
    	if ( $self->user_exists($user)) {
    	    my $o = $self->DB->{$user};
    	    if (ref $o->Groups ne 'ARRAY') {
    		if (defined $o->Groups) {
    		    $o->Groups([$o->Groups, $group]);
    		} else {
    		    $o->Groups([$group]);
    		}
    	    } else {
    		my $groups = $o->Groups;
    		push @$groups, $group;
    	    }
    	    $self->DB->{$user} = $o;
    	    $ret=1;
    	}
    	return $ret;
    });
}

sub set_groups {
    my($self, $user, @groups) = @_;

    if ( $self->InvalidGroupChars ne '' ) {
	my $rcrx = "[" . quotemeta($self->InvalidGroupChars) . "]";
	for my $group (@groups) {
	    if ($group =~ /$rcrx/) {
		die "Invalid characters (some of @{[ $self->InvalidGroupChars ]} in group name";
	    }
	}
    }

    $self->connect_if_necessary(sub {
	my $ret = 0;
    	if ($self->user_exists($user)) {
    	    my $o = $self->DB->{$user};
	    $o->Groups(\@groups);
    	    $self->DB->{$user} = $o;
    	    $ret = 1;
    	}
    	return $ret;
    });
}

sub delete_group {
    my($self, $user, $delgroup) = @_;
    $self->connect_if_necessary(sub {
    	my $ret=0;
    	if ( $self->user_exists($user) && $self->is_in_group($user,$delgroup)) {
    	    my $o = $self->DB->{$user};
    	    my @groups = $self->get_groups($user);
    	    my @newgroups;
    	    foreach my $g (@groups) {
    		if ($g ne $delgroup) { push(@newgroups,$g) }
    	    }
    	    $o->Groups(\@newgroups);
    	    $self->DB->{$user} = $o;
    	    $ret=1;
    	}
    	return $ret;
    });
}

sub get_users_of_group {
    my($self, $group) = @_;
    $self->connect_if_necessary(sub {
    	my @users;
    	foreach my $usr (keys %{$self->DB}) {
    	    next if $usr =~ /^__/; # skip special keys
    	    if ( $self->is_in_group($usr,$group) ) { push(@users,$usr); }
    	}
    	return @users;
    });
}

sub get_all_users {
    my($self) = @_;
    $self->connect_if_necessary(sub {
    	my @allusers;
    	foreach my $usr (keys %{$self->DB}) {
    	    next if $usr =~ /^__/; # skip special keys
    	    push(@allusers, $usr);
    	}
    	return @allusers;
    });
}

sub get_all_groups {
    my($self) = @_;
    $self->connect_if_necessary(sub {
        $self->_init_groups;
	sort keys %{ $self->DB->{GROUPS_KEY()} };
    });
}

sub _crypt {
    my($password, $salt) = @_;
    $password = "" if !defined $password;
    my $crypt;
    eval {
	local $SIG{__DIE__};
	$crypt = crypt($password, $salt);
    };
    if ($@) { $crypt = $password };
    $crypt;
}

sub _encrypt {
    my($self, $password) = @_;
    if ($self->CryptMode eq 'none') {
	$password;
    } else {
	_crypt($password, &salt);
    }
}

sub _decrypt {
    my($self, $checkit, $old_password) = @_;
    if ($self->CryptMode eq 'none') {
	if ($checkit eq $old_password) {
	    $old_password;
	} else {
	    $checkit.$old_password."DUMMY"; # construct a wrong result
	}
    } else {
	_crypt($checkit, $old_password);
    }
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

sub error {
    my($self, $errorcode) = @_;
    my @errtxt = ("not accepted", # 0
		  "ok",
		  "invalid character",
		  "group already exists",
		 );

    if ( $errtxt[$errorcode] ) {
	return $errtxt[$errorcode];
    } else {
	return "unknown error.";
    }
    return 0;
}

# Return 1 if this file is really a WE::DB::ComplexUser file
sub check_data_format {
    my $self = shift;
    if (scalar keys %{ $self->DB } == 0) {
	return 1; # empty
    }
    exists $self->DB->{__DBINFO__} ? 1 : 0;
}

sub _init_groups {
    my $self = shift;
    $self->connect_if_necessary(sub {
	if (!exists $self->DB->{GROUPS_KEY()}) {
	    $self->DB->{GROUPS_KEY()} =
		{
		 map {
		     my $o = $self->GroupObjClass->new;
		     $o->Groupname($_);
		     ($_ => $o);
		 } $self->_predefined_groups
		};
	}
    });
}

sub delete_all_groups {
    my $self = shift;
    $self->connect_if_necessary(sub {
        $self->DB->{GROUPS_KEY()} = { };
	for my $u_name ($self->get_all_users) {
	    $self->DB->{$u_name}{Groups} = [];
	}
    });
}

sub _predefined_groups {
    qw(editor chiefeditor admin);
}

sub delete_group_definition {
    my($self, $group) = @_;
    $self->connect_if_necessary(sub {
	my $groups = $self->DB->{GROUPS_KEY()};
        delete $groups->{$group};
	$self->DB->{GROUPS_KEY()} = $groups;
	for my $u_name ($self->get_all_users) {
	    my @groups = $self->get_groups($u_name);
	    my $before = scalar @groups;
	    @groups = grep { $_ ne $group } @groups;
	    if ($before != scalar @groups) { # a group was deleted
		my $u = $self->DB->{$u_name};
		$u->{Groups} = \@groups;
		$self->DB->{$u_name} = $u;
	    }
	}
	return ERROR_OK;
    });
}

sub add_group_definition {
    my($self, $group) = @_;
    my $group_object;
    if (UNIVERSAL::isa($group, $self->GroupObjClass)) {
	$group_object = $group;
	$group = $group_object->Groupname;
	if (!defined $group) {
	    die "Groupname is empty in group object";
	}
    } else {
	$group_object = $self->GroupObjClass->new;
	$group_object->Groupname($group);
    }
    $self->connect_if_necessary(sub {
	$self->_init_groups;
	my @groups = keys %{ $self->DB->{GROUPS_KEY()} };
        if (grep { $_ eq $group } @groups) {
	    return ERROR_GROUP_EXISTS;
	}
	my $groups = $self->DB->{GROUPS_KEY()};
	$groups->{$group} = $group_object;
	$self->DB->{GROUPS_KEY()} = $groups;
	return ERROR_OK;
    });
}

sub get_group_definition {
    my($self, $group) = @_;
    $self->connect_if_necessary(sub {
	$self->_init_groups;
	my $groupdef = $self->DB->{GROUPS_KEY()}{$group};
	$groupdef;
    });
}

sub set_group_definition {
    my $self = shift;
    my($group, $o);
    if (@_ == 1) {
	$o = $_[0];
	$group = $o->Groupname;
    } else {
	($group, $o) = @_;
    }    
    $self->connect_if_necessary(sub {
    	my $groups = $self->DB->{GROUPS_KEY()};
	$groups->{$group} = $o;
	$self->DB->{GROUPS_KEY()} = $groups;
    	$o;
    });
}

sub set_password {
    my($self, $entity_obj, $password) = @_;
    my $crypted_password = $self->_encrypt($password);
    $entity_obj->Password($crypted_password);
}

1;

__END__

=head1 NAME

WE::DB::ComplexUser - Webeditor user database.

=head1 SYNOPSIS

    use WE::DB::ComplexUser;
    my $udb = WE::DB::ComplexUser->new($root_db, $user_db_file, %args);
   
=head1 DESCRIPTION

Object for administration of webeditor-users. You can add, delete,
identify, modify users. This is an MLDBM implementation of the
L<WE::DB::User> module.

B<NOTE> Due to histerical reasons, the returned value of most methods
is not a boolean value as one would expect. Rather the C<ERROR_*>
constants should be used instead, see L</CONSTANTS>.

=head2 User objects

The user elements are objects of the class C<WE::UserObj> (this may be
changed by overriding the UserObjClass method) objects with the
following members:

=over 4

=item Username

The short name for the user.

=item Password

The (probably crypted) password.

=item Realname

The full name of the user.

=item Groups

An array reference to the groups of this user.

=item Roles

An array reference to the roles of this user.

=item Email

The email address of the user.

=item Homedirectory

The home directory of the user. This may be the classical UNIX home
directory, or the default starting point in the web.editor tree
hierarchy.

=item Shell

The shell of the user. This may be the classical UNIX shell.

=item Language

The preferred language of the user. This should be a string or an
array of languages.

=item AuthType

The authentication type of the user. The default (undef, empty string
or "userdb") means to use the Password entry of the ComplexUser
database. For other values an external module is consulted, which is
named C<WE::DB::ComplexUser::AuthI<authtype>>. See
L<WE::DB::ComplexUser::AuthPOP3> and L<WE::DB::ComplexUser::AuthUnix>.

=item Id

An automatically increased identifier, which is set when adding the
object to the database. Note that the Username is used to identify an
user object, not the Id.

=back

=head2 Group objects

There's also elements of the class C<WE::GroupObj> for group objects.
The group objects have the following members:

=over

=item Groupname

The full name of the group

=item Description

A description of the group's purpose

=item Id

An Id, see the WE::UserObj description for Id.

=back

Note that accessing C<WE::GroupObj> objects is not very efficient,
especially for databases with a large group number.

=head2 CONSTRUCTOR

    my $udb = WE::DB::ComplexUser->new($root_db, $user_db_file, %args);

The I<$root_db> argument is optional and should be either C<undef> or
a L<WE::DB> object.

The I<$user_db_file> is the pathname to the database file.

Remaining arguments may be:

=over

=item -crypt => 'crypt'

Use L<crypt|perlfunc/"crypt PLAINTEXT"> for crypting password (default).

=item -crypt => 'none'

Do not crypt passwords.

=back

=head2 METHODS

=over

=item $udb->add_user($username,$password,$fullrealname)

This is deprecated, use L<< /$udb->add_user_object >> instead.

Add a user with the specified I<$username>, I$<password> and
I<$fullrealname>. Return ERROR_OK if creation of user was successful.
Die on errors (e.g. if invalid characters or an invalid username is
used).

=item $udb->add_user_object($o)

Add a user with the specified C<WE::UserObj> object. Return ERROR_OK
if creation of user by object was successful. See L<< /$udb->add_user
>> for exceptions.

=item $udb->get_fullname($username)

Return string with full reallife name.

=item $udb->identify($username,$entered_password)

Identify the given I<$username> with the I<$entered_password> and return
1 (ERROR_OK), if the authentication was successful.

=item $udb->identify_object($username,$entered_password)

Identify the given I<$username> with the I<$entered_password> and
return the user object, if the authentication was successful.

=item $udb->user_exists($username)

Return 1 if the specified I<$username> exists.

=item $udb->delete_user($username)

Delete the specified I<$username>. Return ERROR_OK if successful.

=item $udb->is_in_group($username,$group)

Return 1 if I<$username> is in the named I<$group>.

=item $udb->get_groups($username)

Return an array of the I<$username>'s groups.

Return 1 if I<$username> is in the named I<$group>.

=item $udb->add_group($username,$group)

Add the given I<$group> to the I<$username>. Return ERROR_OK if adding
group to user was successful. Note: there's no check if the named
group really exists. Die if invalid characters are used.

=item $udb->set_groups($username, @groups)

Replace I<$username>'s group list with I<@groups>. Die if invalid
characters are used.

=item $udb->delete_group($username,$group)

Delete the given I<$group> from the I<$username>'s group list. Return
ERROR_OK if deleting group was successful.

=item $udb->get_users_of_group($group)

Return an array of usernames belonging to this I<$group>.

=item $udb->get_all_users()

Return an array of all existing users.

=item $udb->get_all_groups()

Return an array of all existing groups.

=item $udb->get_user_object($user)

Return a C<WE::UserObj> object for the given I<$user>, or C<undef>.

=item $udb->set_user_object($o)

=item $udb->set_user_object($user, $o)

Replace the user I<$user> with the C<WE::UserObj> object I<$o>. In the
first form, the username is taken from I<$o>. Return the user object
or die on errors.

=item $udb->delete_all_groups

Delete all existing groups (globally and for each user).

=item $udb->delete_group_definition($group)

Delete the named I<$group> (globally and for each user).

=item $udb->add_group_definition($group, %args)

Add a new I<$group> globally. I<%args> is unused for now.

=item $udb->get_group_definition($group)

Return the I<$group> definition as a hash reference or C<undef>.

=item $udb->set_group_definition($group, $o)

Replace the group definition I<$o> for the given I<$group>.

=item $udb->_predefined_groups

Return an array with predefined groups. This method may be overridden
by a sub class.

=item $udb->set_password($userobj, $password)

Set the I<$password> in the given I<$userobj>. Depending on the crypt
mode of the user database, this will be encrypted or unencrypted. Does
not save the I<$userobj> into the database. Use this method instead of
setting the I<Password> member in the I<$userobj> directly.

=item $udb->ErrorType([$error_type])

Set how errors are handled:

=over

=item ERROR_TYPE_DIE

If errors are encountered, the method will die. This is the default.

=item ERROR_TYPE_RETURN

If errors are encountered, the method will return with an error code.
The error message can be fetched by C<< $udb->ErrorMsg >>.

=back

Without argument return the current value.

=back

=head2 CONSTANTS

These error constants may be used, either fully qualified or as static
methods:

=over

=item * ERROR_NOT_ACCEPTED

=item * ERROR_OK

=item * ERROR_INVALID_CHAR

=item * ERROR_GROUP_EXISTS

=item * ERROR_USER_EXISTS

=back

=head1 HISTORY

An incompatible change occurred around 2005-02-16 (between version
2.19 and 2.20): adding an existing user used to return "0", but now it
returns C<ERROR_USER_EXISTS>.

=head1 AUTHORS

Olaf Mätzner - maetzner@onlineoffice.de,
Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>, L<WE::DB::User>

=cut

