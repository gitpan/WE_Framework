# -*- perl -*-

#
# $Id: Name.pm,v 1.11 2004/02/26 11:10:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::DB::Name;

use base qw(WE::DB::Base);

use strict;
use vars qw($VERSION $TIMEOUT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors(qw(DBFile DBTieArgs));

use DB_File;
use Fcntl;

=head1 NAME

WE::DB::Name - a name to id database

=head1 SYNOPSIS

    new WE::DB::Name $rootdb, $databasefilename;

=head1 DESCRIPTION

A class for a name-to-id database.

=head2 CONSTRUCTOR new($class, $root, $file, %args)

Usually called from C<WE::DB>.

=cut

sub new {
    my($class, $root, $file, %args) = @_;

    # XXX -db is not used yet! it's always DB_File for now
    $args{-db}         = "DB_File" unless defined $args{-db};
    $args{-connect}    = 1 unless defined $args{-connect};
    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};

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

    $self->DBFile($file);
    $self->DBTieArgs(\@tie_args);

    $self->Root($root);
    $self->Connected(0);

    if ($args{-connect} && $args{-connect} ne 'never') {
	$self->connect;
    }

    $self;
}

=head2 METHODS

=over 4

=item insert($name, $id)

Set a name for the specified id.

=cut

sub insert {
    my($self, $name, $id) = @_;
    $self->connect_if_necessary(sub {
        $self->{DB}{$name} = $id;
    });
}

=item delete($name)

Delete the specified name from the database

=cut

sub delete {
    my($self, $name) = @_;
    $self->connect_if_necessary(sub {
        delete $self->{DB}{$name};
    });
}

=item get_id($name)

Get the id for the specified name, or return undef, if there is no
such name in the database.

=cut

sub get_id {
    my($self, $name) = @_;
    $self->connect_if_necessary(sub {
        $self->{DB}{$name};
    });
}

=item get_names($id)

Return an array of all names for the specified object id.

=cut

sub get_names {
    my($self, $id) = @_;
    my @names;
    $self->connect_if_necessary(sub {
	while(my($name,$this_id) = each %{ $self->{DB} }) {
	    if ($id == $this_id) {
		push @names, $name;
	    }
	}
    });
    @names;
}

=item update($add_objects, $del_objects)

Update of the database by adding all names from C<$add_objects> and
deleting all names from C<$del_objects>. C<$add_objects> and
C<$del_objects> are array references with C<WE::Obj> objects.

=cut

sub update {
    my($self, $add_objects, $del_objects) = @_;
    for my $o (@$del_objects) {
	if (defined $o->Name && $o->Name ne "") {
	    $self->delete($o->Name);
	}
    }
    for my $o (@$add_objects) {
	if (defined $o->Name && $o->Name ne "") {
	    $self->insert($o->Name, $o->Id);
	}
    }
}

=item rebuild_db_contents($objdb)

Complete rebuild of the name database from the object database.
C<$objdb> is optional, by default the standard C<ObjDB> of the C<Root>
is used.

=cut

sub rebuild_db_contents {
    my($self, $objdb) = @_;
    $self->delete_db_contents;

    if (!$objdb) {
#	$objdb = $self->Root->ObjDB;#XXX not working... why?
	$objdb = $self->{Root}->ObjDB;
    }
    if (!$objdb) {
	die "No object database reference specified";
    }

    $self->connect_if_necessary(sub {
        $objdb->walk($objdb->root_object->Id, sub {
	    my($id) = @_;
	    my $obj = $objdb->get_object($id);
	    my $name = $obj->Name;
	    if (defined $name && $name ne "") {
		$self->{DB}{$name} = $obj->Id;
	    }
	});
    });
}

=item delete_db_contents

Delete all database contents

=cut

sub delete_db_contents {
    my $self = shift;
    $self->connect_if_necessary(sub {
        my(@todel) = keys %{$self->{DB}};
	foreach (@todel) {
	    delete $self->{DB}{$_};
	}
    });
}

#XXX del:
#  sub delete_db {
#      my $self = shift;
#      unlink $self->DBFile;
#  }

sub connect {
    my $self = shift;
    tie %{$self->{DB}}, "DB_File", $self->DBFile, @{$self->DBTieArgs}
	or die("Can't tie DB_File database @{[$self->DBFile]} with args <@{$self->DBTieArgs}>: $!");
    $self->Connected(1);
}

#  sub connect_if_necessary {
#      my($self, $sub) = @_;
#      my $connected = $self->Connected;
#      my $do_disconnect;
#      if (!$connected) {
#  	$self->connect;
#  	$do_disconnect=1;
#      }
#      my $wantarray = wantarray;
#      my @r;
#      eval {
#  	if ($wantarray) {
#  	    @r = $sub->();
#  	} else {
#  	    $r[0] = $sub->();
#  	}
#      };
#      my $err = $@;
#      if ($do_disconnect) {
#  	$self->disconnect;
#      }
#      if ($err) {
#  	die $err;
#      }
#      if ($wantarray) {
#  	@r;
#      } else {
#  	$r[0];
#      }
#  }

=item disconnect

Disconnect the database. No further access on the database may be done.

=cut

sub disconnect {
    my $self = shift;
    if ($self->Connected) {
	eval {
	    untie %{ $self->{DB} };
	};warn $@ if $@;
	$self->Connected(0);
    }
}

=item all_names

Return an array with all used names.

=cut

sub all_names {
    my $self = shift;
    $self->connect_if_necessary(sub {
        keys %{ $self->{DB} };
    });
}

=item exists

Return true if the name is already occupied.

=cut

sub exists {
    my($self, $name) = @_;
    $self->connect_if_necessary(sub {
        exists $self->{DB}->{$name};
    });
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

