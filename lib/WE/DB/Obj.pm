# -*- perl -*-

#
# $Id: Obj.pm,v 1.37 2005/01/28 08:44:07 eserte Exp $
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

=head1 NAME

WE::DB::Obj - object database for the WE_Framework

=head1 SYNOPSIS

    $objdb = WE::DB::Obj->new($root, $db_file);
    $objdb = $root->ObjDB;

=head1 DESCRIPTION

=cut

package WE::DB::Obj;
use base qw(WE::DB::ObjBase);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.37 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors(qw(DBFile DBTieArgs
			     MLDBM_Serializer MLDBM_UseDB MLDBM_DumpMeth
			     IsCachedDatabase));

use MLDBM;
use Fcntl;

use WE::Util::Date;
use WE::Util::LangString qw(new_langstring langstring);

use constant OBJECT   => 0;
use constant CHILDREN => 1;
use constant PARENTS  => 2;
use constant VERSIONS => 3;

sub DBClass { "DB_File" }
sub SerializerClass { "Data::Dumper" }

=head2 CONSTRUCTOR new($class, $root, $file [, %args])

C<new> creates a new database reference object (and, if the database
does not exist, also the physical database). Usually called only from
L<WE::DB (see there)|WE::DB>. Parameters are: the C<$root> object (a
C<WE::DB> object) and the filename for the underlying database (here,
it is C<MLDBM>).

In the optional arguments, further options can be specified:

=over 4

=item -serializer => $serializer

The type of the serializer, e.g. C<Data::Dumper> (the default) or
C<Storable>.

=item -db => $db

The type of the database (dbm) implementation, e.g. C<DB_File> (the
default) or C<GDBM_File>. Note that other databases than C<DB_File> or
C<GDBM_File> have length restrictions, making them unsuitable for
using with C<WE::DB::Obj>. However, the CPAN module
C<MLDBM::Sync::SDBM_File> workaround the deficiency of the 1K size
limit in the standard C<SDBM_File> database.

=item -locking => $bool

True, if locking should be used. XXX For now, only 0 and 1 can be
used, but this should probably be changed to use shared and exclusive
locks.

By default, there is no locking. If locking is enabled and the
database type is C<DB_File>, then C<DB_File::Lock> will be used. For
other database types, no locking is implemented.

=item -readonly => $bool

Open the database read-only. This is the same as specifying O_RDONLY.
By default it is opened read-write and the database is created if
necessary (O_RDWR|O_CREAT).

=item -writeonly => $bool

If true, then a database will not be created if necessary. This is the
same as specifying O_RDWR.

=item -connect => $bool

If true, connects to the database while constructing the object.
Otherwise the connection will be made automatically before each
operation. Also, the methods B<connect> and B<disconnect> can be used
for connecting and disconnecting from the database.

Normally, long running processes (servers or mod_perl processes)
should specify -connect => 0 and use the auto-connection feature or
manually connect()/disconnect(). So database changes are propagated
immediately.

The default of the -connect option is true.

=back

=cut

sub new {
    my($proto, $root, $file, %args) = @_;
    my $class = ref $proto || $proto;
    my $self = {};
    bless $self, $class;

    $args{-db}         = $self->DBClass
	unless defined $args{-db};
    $args{-serializer} = $self->SerializerClass
	unless defined $args{-serializer};
    $args{-locking}    = 0 unless defined $args{-locking};
    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};
    $args{-connect}    = 1 unless defined $args{-connect};
    if (!$args{-readonly} && $args{-cache}) {
	die "-cache => 1 is only allowed with -readonly";
    }
    $args{-cache}      = 0 unless defined $args{-cache};

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
	    $self->MLDBM_UseDB('DB_File::Lock');
	    push @tie_args, $args{-readonly} ? "read" : "write";
	} else {
	    $self->MLDBM_UseDB('DB_File');
	}
    } else {
	$self->MLDBM_UseDB($args{-db});
    }

    $self->MLDBM_Serializer($args{-serializer});
    if ($self->MLDBM_Serializer eq 'Storable') {
	$self->MLDBM_DumpMeth('portable');
    }

    $self->DBFile($file);
    $self->DBTieArgs(\@tie_args);

    $self->Root($root);
    $self->Connected(0);

    if ($args{-cache}) {
	my $cached_db = {};
	$self->connect;
	while(my($k,$v) = each %{ $self->{DB} }) {
	    $cached_db->{$k} = $v;
	}
	$self->disconnect;
	$self->{DB} = $cached_db;
	$self->Connected(1);
	$self->IsCachedDatabase(1);
	return $self;
    }

    if ($args{-connect} && $args{-connect} ne 'never') {
	$self->connect;
    }

    $self;
}

sub cached_db {
    my($self) = @_;
    my $db = ($self->MLDBM_UseDB eq 'DB_File::Lock'
	      ? 'DB_File'
	      : $self->MLDBM_UseDB
	     );
    $self->new($self->Root,
	       $self->DBFile,
	       -readonly => 1,
	       -cache => 1,
	       -db => $db,
	       -serializer => $self->MLDBM_Serializer,
	      );
}

=head2 DESTRUCTOR DESTROY

Called automatically. Destroys the tied database handle.

=cut

### XXX DESTROY seems to throw segfaults now (because of disconnect??? the
### XXX eval in disconnect???)
#  sub DESTROY {
#      my $self = shift;
#      $self->Root(undef);

#      #XXXlocal $^W = undef; # XXX
#      $self->disconnect;
#  #      if ($self->{DB} && ref $self->{DB} eq 'HASH' && tied %{$self->{DB}}) {
#  #  	untie %{ $self->{DB} };
#  #      }
#  }

=head2 METHODS

Please see also L<WE::DB::ObjBase> for inherited methods.

=over 4

=item connect

=cut

sub connect {
    my $self = shift;
    local $MLDBM::UseDB = $self->MLDBM_UseDB;
    local $MLDBM::Serializer = $self->MLDBM_Serializer;
    local $MLDBM::DumpMeth = $self->MLDBM_DumpMeth;

    my @args = @{$self->DBTieArgs};
    tie %{ $self->{DB} }, 'MLDBM', $self->DBFile, @args
	or die "Can't tie MLDBM database @{[$self->DBFile]} with args <@args>, db <$MLDBM::UseDB> and serializer <$MLDBM::Serializer>: $!";
    $self->Connected(1);
}

=item disconnect

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

=item init

Initialize the database to hold meta data like _root_object or
_next_id. Usually called only from C<WE::DB>.

=cut

# XXX hardcoded to create a site...
sub init {
    my($self, %args) = @_;

    if (!$self->root_object) {
	$self->connect_if_necessary
	    (sub {
		 my $site = WE::Obj::Site->new();

		 # XXX hmmmm... should not be doubled...
		 my $now = epoch2isodate();
		 $site->TimeCreated($now);
		 $site->TimeModified($now);
		 $site->Owner($self->Root->CurrentUser);
		 my $title = $args{-title} ||
		             new_langstring(en => "Root of the site",
					    de => "Wurzel der Website",
					   );
		 $site->Title($title);
		 my $obj = $self->_store_obj($site);
		 $self->{DB}{'_root_object'} = $obj->[OBJECT]->Id;
	     });
    }
}

=item delete_db_contents

Delete all database contents

=cut

sub delete_db_contents {
    my $self = shift;
    $self->connect_if_necessary
	(sub {
	     my @obj = keys %{ $self->{DB} };
	     foreach (@obj) {
		 delete $self->{DB}{$_};
	     }
	     $self->init;
	 });

    # update names, links ...
    if ($self->Root->NameDB) {
	$self->Root->NameDB->delete_db_contents;
    }
}

=item root_object

Return the root object.

=cut

sub root_object {
    my($self) = @_;
    # XXX permission manager
    $self->connect_if_necessary
	(sub {
	     if (exists $self->{DB}{'_root_object'}) {
		 $self->get_object($self->{DB}{'_root_object'});
	     } else {
		 undef;
	     }
	 });
}

=item is_root_object($objid)

Return true if the object with id C<$objid> is the root object.

=cut

sub is_root_object {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    $self->connect_if_necessary
	(sub {
	     $self->{DB}{'_root_object'} eq $objid;
	 });
}

=item _next_id

Increment and get the next free id. The internal id counter is always
incremented, regardless whether the new id will be used or not.

=cut

sub _next_id {
    my($self) = @_;
    $self->connect_if_necessary
	(sub {
	     my $id = $self->{DB}->{'_next_id'} || 0;
	     $self->{DB}->{'_next_id'}++;
	     $id;
	 });
}

=item _get_next_id

Only get the next free id, without incrementing it.

=cut

sub _get_next_id {
    my($self) = @_;
    $self->connect_if_necessary
	(sub {
	     $self->{DB}->{'_next_id'};
	 });
}

=item _create_stored_obj

Create a new internal stored object.

=cut

sub _create_stored_obj {
    my($self) = @_;
    [undef, [], [], []];
}

=item _store_stored_obj($stored_object)

Store the internal stored object.

=cut

sub _store_stored_obj {
    my($self, $stored_obj) = @_;
    my $id = $stored_obj->[OBJECT]->Id;
    if (!defined $id) {
	die "Fatal error: there is no Id in the stored object";
    }
    $self->connect_if_necessary
	(sub {
	     $self->{DB}{$id} = $stored_obj;
	 });
}

=item _store_obj($object)

Store the object. Please note that there is a difference between a
stored object (holding additional data like children, parents etc.)
and the mere object.

=cut

sub _store_obj {
    my($self, $obj) = @_;
    $self->connect_if_necessary
	(sub {
	     my $id = $obj->Id;
	     if (!defined $id) {
		 $id = $self->_next_id;
		 $obj->Id($id);
	     }
	     my $o = $self->{DB}{$id};
	     if (!$o) {
		 $o = [];
		 $o->[PARENTS]  = [];
		 $o->[CHILDREN] = [];
		 $o->[VERSIONS] = [];
	     }
	     $o->[OBJECT]   = $obj;

	     $self->{DB}{$id} = $o;

	     # return stored object
	     $o;
	 });
}

=item _get_stored_obj($object_id)

Get a stored object.

=cut

sub _get_stored_obj {
    my($self, $id) = @_;
    $self->connect_if_necessary
	(sub {
	     $self->{DB}{$id};
	 });
}

=item get_object($object_id)

Get an object by id.

=cut

sub get_object {
    my($self, $obj_id) = @_;
    my $o = $self->_get_stored_obj($obj_id);
    $o ? $o->[OBJECT] : undef;
}

=item exists($object_id)

Return true if the object exists. Parameter is the object id.

=cut

sub exists {
    my($self, $obj_id) = @_;
    defined $self->_get_stored_obj($obj_id);
}

=item children_ids($object_id)

Return a list of the children ids of this object. If the object does
not exist or the object has not children, return an empty list.

=cut

sub children_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->_get_stored_obj($obj_id);
    $o ? @{ $o->[CHILDREN] } : ();
}

=item parent_ids($object_id)

Like children_ids, but return parent ids instead.

=cut

sub parent_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->_get_stored_obj($obj_id);
    $o ? @{ $o->[PARENTS] } : ();
}

=item version_ids($object_id)

Like children_ids, but return version ids instead.

=cut

sub version_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->_get_stored_obj($obj_id);
    $o ? @{ $o->[VERSIONS] } : ();
}

=item find_links($target_id)

Find links with the $target_id as target.

=cut

sub find_links {
    my($self, $target_id) = @_;
    $self->idify_params($target_id);
    my @obj_ids;
    if ($self->Root->LinkDB) {
	@obj_ids = $self->Root->LinkDB->find_links($target_id);
    } else {
	$self->connect_if_necessary
	    (sub {
		 while(my($id, $stored_obj) = each %{ $self->{DB} }) {
		     next if $id =~ /^_/;
		     foreach my $idx (PARENTS, CHILDREN, VERSIONS) {
			 foreach (@{ $stored_obj->[$idx] }) {
			     if ($_ eq $target_id) {
				 push @obj_ids, $stored_obj->[OBJECT]->Id;
				 next;
			     }
			 }
		     }
		 }
	     });
    }
    @obj_ids;
}

sub _remove_from_link_array {
    my($self, $id, $stored_obj) = @_;
    foreach my $idx (PARENTS, CHILDREN, VERSIONS) {
	my $i = 0;
	foreach (@{ $stored_obj->[$idx] }) {
	    if ($_ eq $id) {
		splice @{ $stored_obj->[$idx] }, $i, 1;
	    }
	    $i++;
	}
    }
}

=item unlink($object_id, $parent_id, %args)

Remove the given parent link from the object. If there is no parent
link anymore, remove the whole object.

Remaining arguments are passed to the B<remove> method (see there).

=cut

sub unlink {
    my($self, $obj_id, $parent_id, %args) = @_;
    $self->idify_params($obj_id, $parent_id);
    my $parent_stored_obj = $self->_get_stored_obj($parent_id);
    die "Can't get parent object with id $parent_id" unless $parent_stored_obj;
    my $stored_obj = $self->_get_stored_obj($obj_id);
    die "Can't get object with id $obj_id" unless $stored_obj;

    my $i = 0;
    foreach (@{ $parent_stored_obj->[CHILDREN] }) {
	if ($_ eq $obj_id) {
	    splice @{ $parent_stored_obj->[CHILDREN] }, $i, 1;
	}
	$i++;
    }
    $self->_store_stored_obj($parent_stored_obj);

    $i = 0;
    foreach (@{ $stored_obj->[PARENTS] }) {
	if ($_ eq $parent_id) {
	    splice @{ $stored_obj->[PARENTS] }, $i, 1;
	}
	$i++;
    }

    if (!@{ $stored_obj->[PARENTS] }) {
	$self->remove($obj_id, %args);
    } else {
	$self->_store_stored_obj($stored_obj);
    }
}

=item link($object_id, $folder_id)

Link an object to a folder. This can be used to create multiple links.
It is possible to create multiple links from one object to another ---
this behaviour may change XXX. See also L</BUGS>.

=cut

# XXX cycle detection is missing
sub link {
    my($self, $obj_id, $folder_id) = @_;
    $self->idify_params($obj_id, $folder_id);
    my $stored_obj = $self->_get_stored_obj($obj_id);
    die "Can't get object with id $obj_id" unless $stored_obj;
    # XXX use insertable types?
    # XXX permission manager
    my $folder_stored_obj = $self->_get_stored_obj($folder_id);
    die "Can't get folder object with id $folder_id" unless $folder_stored_obj;
    push @{ $stored_obj->[PARENTS] }, $folder_id;
    push @{ $folder_stored_obj->[CHILDREN] }, $obj_id;
    $self->_store_stored_obj($stored_obj);
    $self->_store_stored_obj($folder_stored_obj);
}

=item remove($object_id, %args)

Remove the object $obj_id and all links to this object uncoditionally.

If -links => "unhandled" is specified, then links to this object won't
get removed. This is dangerous, and needs an additional L<we_fsck> run
afterwards. This option is useful if a mass-delete should be done.

=cut

sub remove {
    my($self, $obj_id, %args) = @_;
    $self->idify_params($obj_id);
    $self->connect_if_necessary
	(sub {
	     my $stored_obj = $self->_get_stored_obj($obj_id);

# XXX Debugging!
if (!$stored_obj->[OBJECT]) {
require Data::Dumper;
warn "SHOULD NOT HAPPEN: object $obj_id has no stored object";
warn Data::Dumper::Dumper($stored_obj);
}

	     # remove content
	     if (UNIVERSAL::isa($stored_obj->[OBJECT], ('WE::Obj::DocObj'))
		 && $self->Root->ContentDB) {
		 $self->Root->ContentDB->remove($stored_obj->[OBJECT]);
	     }

	     # unlink children
	     foreach my $child_id (@{ $stored_obj->[CHILDREN] }) {
		 $self->unlink($child_id, $obj_id);
	     }

	     # delete everything in name database
	     if ($self->Root->NameDB) {
		 my $o = $self->get_object($obj_id);
		 $self->Root->NameDB->update([], [$o]);
	     }

	     # delete physical object
	     delete $self->{DB}{$obj_id};

	     # delete remaining links
	     if (!$args{'-links'} || $args{'-links'} ne "unhandled") {
		 my @obj_ids = $self->find_links($obj_id);
		 foreach my $id (@obj_ids) {
		     my $stored_obj = $self->_get_stored_obj($id);
		     $self->_remove_from_link_array($obj_id, $stored_obj);
		     $self->_store_stored_obj($stored_obj);
		 }
	     }

	 });
}

=item insert_doc(%args)

Insert a document.
The following arguments should be given:

    -content: a string to the content or
    -file:    the filename for the content
    -parent:  the id of the parent

Other arguments will be used as attributes for the object, e.g.
-ContentType will be used as the ContentType attribute and -Title as
the title attribute. Note that these attributes are typically starting
with an uppercase letter.

Return the generated object.

=cut

sub insert_doc {
    my($self, %args) = @_;
    my $doc = WE::Obj::Doc->new;
    $self->insert_doc_obj($doc, %args);
}

sub insert_doc_obj {
    my($self, $doc, %args) = @_;

    # XXX permission manager
    my $content = delete $args{-content};
    my $file    = delete $args{-file};
    my $parent  = delete $args{-parent};
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	$doc->{ucfirst(substr($k,1))} = $v;
    }
    if (defined $file) {
	$doc->{ContentType} = $self->Root->ContentDB->get_mime_type_by_filename($file) if !$doc->{ContentType};
	open(F, $file) or die "Can't open file $file: $!";
	local $/ = undef;
	$content = <F>;
	close F;

	require File::Basename;
	my $base = File::Basename::basename($file);

	# auto set title
	if (!defined $doc->{Title}) {
	    if ($base =~ /^(.+)(\.[^.]+)$/) {
		$doc->{Title} = $1; # stripped extension
	    } else {
		$doc->{Title} = $base; # there is no extension
	    }
	}

	if (!defined $doc->{Basename}) {
	    $doc->{Basename} = $base;
	}
    }

    $doc->ContentType("text/html") if !$doc->{ContentType}; # i.e. content given
    $self->insert($doc, -parent => $parent);
    $self->Root->ContentDB->store($doc, $content);
    $doc;
}

=item insert_folder(%args)

Insert a folder.
The following arguments should be given:

    -parent:  the id of the parent

Return the generated object.

=cut

sub insert_folder {
    my($self, %args) = @_;
    my $folder = WE::Obj::Folder->new;
    # XXX permission manager
    my $parent = delete $args{-parent};
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	my $member = ucfirst(substr($k,1));
	if ($folder->can($member)) {
	    $folder->$member($v);
	} else {
	    $folder->{$member} = $v;
	}
    }

### XXX autogenerate basename here?
#      if (!defined $folder->{Basename}) {
#  	$folder->{Basename} = langstring($folder->{Title}, $self->Root->CurrentLang);
#      }

    $self->insert($folder, -parent => $parent);
}

=item insert($object, %args)

General method for inserting objects. You will mostly use either
insert_doc or insert_folder.

Arguments: C<-parent> for parent object.

Return the generated object.

=cut

sub insert {
    my($self, $obj, %args) = @_;

    $self->connect_if_necessary(sub {
        my $parent  = delete $args{-parent};
	if (!defined $parent) {
	    die "The -parent option is missing";
	}
	$self->idify_params($parent);
	my $parent_stored_obj = $self->_get_stored_obj($parent);
	if (!$parent_stored_obj) {
	    die "There is no parent with id $parent";
	}
	my $parent_obj = $parent_stored_obj->[OBJECT];
	if (!$parent_obj->isa("WE::Obj::FolderObj")) {
	    die "The object with the id $parent is not a FolderObj, but a " . ref $parent_obj . ". Objects can only be inserted in folders.";
	}
	if (!$parent_obj->object_is_insertable($obj)) {
	    die "The object type " . ref($obj) . " is not allowed in " . ref($parent_obj) . ". The only allowed object types are: " . join(", ", @{ $parent_obj->insertable_types });
	}
	my $id = $self->_next_id;
	push @{$parent_stored_obj->[CHILDREN]}, $id;
	$self->_store_stored_obj($parent_stored_obj);

	$obj->Id($id);
	my $owner = $self->Root->CurrentUser;
	if (defined $owner) {
	    $obj->Owner($owner);
	} else {
	    $obj->Owner(undef); # no owner
	}
	my $now = epoch2isodate();
	$obj->TimeCreated($now);
	$obj->TimeModified($now);
	my $obj_stored_obj = $self->_create_stored_obj;
	$obj_stored_obj->[OBJECT] = $obj;
	$obj_stored_obj->[PARENTS] = [$parent];
	$self->_store_stored_obj($obj_stored_obj);

	# update names, links ...
	if ($self->Root->NameDB) {
	    $self->Root->NameDB->update([$obj],[]);
	}
    });

    $obj;
}

sub _insert_version {
    my($self, $obj, %args) = @_;

    my $version_parent = delete $args{-versionparent};
    $self->idify_params($version_parent);
    my $parent_stored_obj = $self->_get_stored_obj($version_parent);
    my $id = $self->_next_id;
    push @{$parent_stored_obj->[VERSIONS]}, $id;
    $self->_store_stored_obj($parent_stored_obj);

    $obj->Id($id);
    $obj->Version_Parent($version_parent);
    my $owner = $self->Root->CurrentUser;
    if (defined $owner) {
	$obj->Version_Owner($owner);
    } else {
	$obj->Version_Owner(undef); # no owner
    }
    my $now = epoch2isodate();
    $obj->Version_Time($now);
    if (defined $args{-log}) {
	$obj->Version_Comment($args{-log});
    }
    if (defined $args{-number}) {
	$obj->Version_Number($args{-number});
    }

    my $obj_stored_obj = $self->_create_stored_obj;
    $obj_stored_obj->[OBJECT] = $obj;
    $self->_store_stored_obj($obj_stored_obj);

    $obj;
}

=item content($object_id)

Get the content for the given object.

=cut

sub content {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    # XXX permission manager
    my $obj = $self->get_object($objid);
    $self->Root->ContentDB->get_content($obj);
}

=item replace_content($object_id, $content)

Replace the content of an existing object. Return the object itself.

=cut

sub replace_content {
    my($self, $objid, $new_content) = @_;
    $self->idify_params($objid);
    my $obj = $self->get_object($objid) || die "Can't get object for id $objid";
    $obj->TimeModified(epoch2isodate());
    $obj->Dirty(1);
    $obj->DirtyContent(1);
    $self->_store_obj($obj);
    $self->Root->ContentDB->store($obj, $new_content);
    $obj;
}

=item flush

Flushes all changes, so they are visible to other processes. This is
done automatically on end of the program or if the object is
destroyed.

=cut

sub flush {
    my $self = shift;
    return if !$self->Connected;
    (tied %{$self->{DB}})->sync;
}

=item replace_object($object)

Replace the given object. Argument is an object. This object should
contain the valid id. Return the object itself.

=cut

sub replace_object {
    my($self, $obj) = @_;
    # XXX permission manager
    my $stored_obj = $self->_get_stored_obj($obj->Id);
    die "Can't get stored object from id " . $obj->Id if !$stored_obj;
    my $namedb = $self->Root->NameDB;
    my $clone;
    if ($namedb) {
	$clone = $stored_obj->[OBJECT]->clone;
    }
    $obj->TimeModified(epoch2isodate());
    $obj->Dirty(1);
    $obj->DirtyAttributes(1);
    $stored_obj->[OBJECT] = $obj;
    $self->_store_stored_obj($stored_obj);

    # update names, links ...
    if ($namedb) {
	$namedb->update([$obj],[$clone]);
    }

    $obj;
}

=item is_ancestor($object_id, $ancestor_id)

Return true if $ancestor_id is an ancestor of $object_id.

=cut

sub is_ancestor {
    my($self, $object_id, $ancestor_id) = @_;
    $self->idify_params($object_id, $ancestor_id);
    my @pathobjects = $self->pathobjects($object_id);
    pop @pathobjects; # remove itself
    for my $o (@pathobjects) {
	return 1 if ($o->Id eq $ancestor_id);
    }
    0;
}

=item copy($object_id, $folder_id, %args)

Copies the object identified by $object_id to the folder identified by
$folder_id. Both the object metadata and the content are copied.
Folders are copied by default recursively. To only copy the folder
object, use C<-recursive =E<gt> 0> in the %args parameter hash.

Return the copied object. If there is a recursive copy, then return a
list of copied objects. In this list, the first object is the copied
top folder. In scalar context, always return only the first (or only)
copied object.

Version information is never copied (yet).

=cut

sub copy {
    my($self, $object_id, $target_id, %args) = @_;
    die "Cannot copy object $object_id into itself"
	if $target_id eq $object_id;
    die "Cannot copy $object_id into descendent object $target_id"
	if $self->is_ancestor($target_id, $object_id);
    $args{-mapping} = {} if !$args{-mapping};
    my @copied = $self->_copy($object_id, -parent => $target_id, %args);
    $self->remap_attribute_links([ values %{ $args{-mapping} } ],
				 $args{-mapping});
    # We have to remap the objects, because they might be changed
    # in remap_attribute_links.
    @copied = map { $self->get_object($_->Id) } @copied;
    wantarray ? @copied : $copied[0];
}

sub remap_attribute_links {
    my($self, $object_ids, $mapping) = @_;
    $self->connect_if_necessary
	(sub {
	     for my $objid (@$object_ids) {
		 my $o = $self->get_object($objid);
		 my $changed;
		 if ($o->can("IndexDoc") &&
		     defined $o->IndexDoc &&
		     exists $mapping->{$o->IndexDoc}) {
		     my $new = $mapping->{$o->IndexDoc};
		     $o->IndexDoc($new);
		     $changed++;
		 }
		 if ($changed) {
		     $self->replace_object($o);
		 }
	     }
	 });
}

=item ci($object_id, %args)

Check in the current version of the object with id C<$object_id>. You
can use additional parameters:

=over

=item -log => $log_message

Specify a log message for this version (recommended). C<-comment> is
an alias for C<-log>.

=item -number => $version_number

Normally, the version number is just incremented (e.g. from 1.0 to
1.1). If you like, you can specify another version number. There are
no checks for valid version numbers (that is, you can specify more
than one number, invalid formatted version numbers etc). C<-version> is an alias for C<-number>.

=item -trimold => $number_of_versions

If set to a value greater 0, then delete old versions. Set
$number_of_versions specify the number of versions you want to keep.
With -trimold => 1, all but the newest version will be wiped out.

=back

Return the checked-in objects. The original object is set to not dirty.

=cut

sub ci {
    my($self, $object_id, %args) = @_;
    if (defined $args{-version}) {
	$args{-number} = delete $args{-version};
    }
    if (!defined $args{-number}) {
	$args{-number} = $self->_get_next_version($object_id);
    }
    if (defined $args{-comment}) {
	$args{-log} = delete $args{-comment};
    }
    my $trimold = delete $args{-trimold};
    my(@ret) = $self->_copy($object_id,
			    -versionparent => $object_id, %args);

    if ($trimold) {
	$self->trim_old_versions($object_id, -trimold => $trimold);
    }

    $self->_undirty($object_id);

    wantarray ? @ret : $ret[0];
}

=item trim_old_versions($object_id, [ -trimold => $number | -all => 1 ])

Trim the last C<$number> versions of object C<$object_id>. If C<-all>
is used instead, then trim all old versions. C<-all> and C<-trimold>
are mutually exclusive.

=cut

# XXX -all is not tested yet!
sub trim_old_versions {
    my($self, $object, %args) = @_;
    $self->objectify_params($object);
    my $object_id = $object->Id;
    my $trimold = delete $args{-trimold};
    my $all     = delete $args{-all};
    if (keys %args) { die "Unknown argument: " . join ", ", keys %args }
    return if !$trimold && !$all;
    my(@versions) = $self->version_ids($object_id);
    if (@versions > 0) { # XXX this used to be @versions>1, but that was probably wrong
	my @newest_ids;
	if ($all) {
	    @newest_ids = ();
	} else {
	    @newest_ids = splice @versions, -$trimold; # don't trim the $trimold newest versions
	}
	foreach my $id (@versions) {
	    $self->remove($id);
	}
eval{
	my $stored_obj = $self->_store_obj($object);
	$stored_obj->[VERSIONS] = [@newest_ids];
	$self->_store_stored_obj($stored_obj);
};die "$@ $object $object_id @versions" if $@;
    }
}

=item co($object_id [, -version => $version_number])

NYI.

Check out the object with the version number C<$version_number>. If
version number is not given, then check out the latest version. If the
version number is not given and there are no versions at all, then an
exception will be thrown. Please note that a check out will override
the current object, so you probably should do a C<ci> first. No
locking is done (yet).

=cut

sub co {
    my($self, $object_id, %args) = @_;
    $self->idify_params($object_id);
    if (defined $args{-version}) {
	$args{-number} = delete $args{-version};
    }
    my $v_obj;
    if (!defined $args{-number}) {
	my @v_id = $self->version_ids($object_id);
	if (!@v_id) {
	    die "There are no versions available for object $object_id";
	}
	$v_obj = $self->get_object($v_id[-1]);
    }
    if (!$v_obj) {
	foreach my $v ($self->versions($object_id)) {
	    if ($v->Version_Number eq $args{-number}) {
		$v_obj = $v;
		last;
	    }
	}
    }
    if (!$v_obj) {
	die "Can't find version $args{-number} for object $object_id";
    }

    my $stored_obj = $self->_get_stored_obj($object_id);
    my $old_o = $stored_obj->[OBJECT];
    $stored_obj->[OBJECT] = $v_obj;
    $self->Root->ContentDB->copy($v_obj, $old_o);
    $v_obj->Id($old_o->Id);
    $self->_store_stored_obj($stored_obj);
    $stored_obj->[OBJECT];
}

sub _copy {
    my($self, $object_id, %args) = @_;
    $self->idify_params($object_id);
    my $obj = $self->get_object($object_id);
    die "Can't find object with id $object_id" if !$obj;

    my $mapping = delete $args{-mapping};

    my %insert_args;
    my $insert_meth;
    if (defined $args{-parent}) {
	my $target_id = delete $args{-parent};
	$self->idify_params($target_id);
	my $target_obj = $self->get_object($target_id);
	die "Target must be a folder" if !$target_obj->is_folder;
	%insert_args = (-parent => $target_id, %args);
	$insert_meth = "insert";
    } else { # new version
	my $version_parent_id = delete $args{-versionparent};
	$self->idify_params($version_parent_id);
	my $target_obj = $self->get_object($version_parent_id);
	die "Target $version_parent_id does not exist" if !$target_obj;
	%insert_args = (-versionparent => $version_parent_id, %args);
	$insert_meth = "_insert_version";
    }

    if ($obj->is_doc) {
	my $content = $self->content($object_id);
	my $clone_obj = $obj->clone;
#XXX	if (grep($_ eq $target_id, $self->parent_ids($object_id))) {
#	    # XXX NYI: change title to "Copy of ..." (lang-dependent)
#           # XXX no: this is also called from ci()!
#	}
	$self->$insert_meth($clone_obj, %insert_args);
	if ($mapping) {
	    $mapping->{$obj->Id} = $clone_obj->Id;
	}
	$self->replace_content($clone_obj, $content);
	$clone_obj;
    } else { # copy folder
	my $clone_obj = $obj->clone;
#XXX	if (grep($_ eq $target_id, $self->parent_ids($object_id))) {
#	    # XXX NYI: change title to "Copy of ..." (lang-dependent)
#           # XXX no: this is also called from ci()!
#	}
	my @ret;
	$self->$insert_meth($clone_obj, %insert_args);
	if ($mapping) {
	    $mapping->{$obj->Id} = $clone_obj->Id;
	}
	push @ret, $clone_obj;
	if (!exists $args{-recursive} || $args{-recursive}) {
	    foreach my $child_id ($self->children_ids($object_id)) {
		if (exists $insert_args{-parent}) {
		    $insert_args{-parent} = $clone_obj->Id;
		} else {
		    $insert_args{-versionparent} = $clone_obj->Id;
		}
		push @ret, $self->_copy($child_id, %insert_args, -mapping => $mapping);
	    }
	}
	@ret;
    }
}

=item move($object_id, $parent_id, %args)

Move the object with C<$object_id> and linked to the parent
C<$parent_id> to another position or destination. If C<$parent_id> is
C<undef>, then the first found parent is used. If there are multiple
parents, then it is better to specify the right one. The C<%args>
portion may look like this:

=over 4

=item -destination => $folder_id

Move the object to another folder. You can also use C<-target> as an
alias for C<-destination>.

=item -after => $after_object_id

Leave the object in the same folder, but move it after the object with
the id C<$after_object_id>. If there is no such object in the folder,
then an exception is raised.

=item -before => $before_object_id

Same as C<-after>, but move the object before the specified object.

=item -to => "begin" | "end"

Move the object to the beginning or end of the folder. For "begin",
you can also use "first" and for "end", you can use "last".

=back

Return nothing. On error an exception will be raised.

=cut

sub move {
    my($self, $objid, $parentid, %args) = @_;
    $self->idify_params($objid);
    if (!defined $parentid) {
	$parentid = ($self->parent_ids($objid))[0];
    }
    $self->idify_params($parentid);

    my $destination = delete $args{-destination};
    if (!defined $destination) {
	$destination = delete $args{-target}; # Alias for -destination
    }
    my $after  = delete $args{-after};
    my $before = delete $args{-before};
    my $to     = delete $args{-to};

    my $check_move = sub {
	my($target_id) = @_;
	die "Cannot move object $objid into itself"
	    if $target_id eq $objid;
	die "Cannot move $objid into descendent object $target_id"
	    if $self->is_ancestor($target_id, $objid);
    };

    # XXX permission manager
    if (defined $destination) {
	$self->idify_params($destination);
	$check_move->($destination);
	# first link, then unlink (in this order!)
	$self->link($objid, $destination);
	$self->unlink($objid, $parentid);
    } elsif (defined $before || defined $after || defined $to) {
	my $parent_stored_obj = $self->_get_stored_obj($parentid);
	my $moved;
	if (defined $after) {
	    $self->idify_params($after);
	    return if $after eq $objid;
	    for(my $i=0; $i<=$#{ $parent_stored_obj->[CHILDREN] }; $i++) {
		my $id = $parent_stored_obj->[CHILDREN][$i];
		if ($id eq $after) {
		    splice @{ $parent_stored_obj->[CHILDREN] }, $i+1, 0, $objid;
		    $moved = 1;
		    $i++;
		} elsif ($id eq $objid) {
		    splice @{ $parent_stored_obj->[CHILDREN] }, $i, 1;
		    $i--;
		}
	    }
	} elsif (defined $before) {
	    $self->idify_params($before);
	    return if $before eq $objid;
	    for(my $i=0; $i<=$#{ $parent_stored_obj->[CHILDREN] }; $i++) {
		my $id = $parent_stored_obj->[CHILDREN][$i];
		if ($id eq $before) {
		    splice @{ $parent_stored_obj->[CHILDREN] }, $i, 0, $objid;
		    $moved = 1;
		    $i++;
		} elsif ($id eq $objid) {
		    splice @{ $parent_stored_obj->[CHILDREN] }, $i, 1;
		    $i--;
		}
	    }
	} elsif (defined $to) {
	    for(my $i=0; $i<=$#{ $parent_stored_obj->[CHILDREN] }; $i++) {
		my $id = $parent_stored_obj->[CHILDREN][$i];
		if ($id eq $objid) {
		    splice @{ $parent_stored_obj->[CHILDREN] }, $i, 1;
		    if ($to =~ /^(begin|first)$/) {
			unshift @{ $parent_stored_obj->[CHILDREN] }, $objid;
			$moved = 1;
			last;
		    } elsif ($to =~ /^(end|last)$/) {
			push @{ $parent_stored_obj->[CHILDREN] }, $objid;
			$moved = 1;
			last;
		    } else {
			die "Invalid -to specification. Must be -first, -last, -begin or -end";
		    }
		}
	    }
	}
	if (!$moved) {
	    die "The object $objid could not be moved in parent $parentid";
	}
	$self->_store_stored_obj($parent_stored_obj);
    } else {
	die "Nowhere to move. Please specify either -destination, -before or -after";
    }
}

=item dump(%args)

Dump object structure as a string. Possible options:

=over 4

=item -root => $object_id

Specify another object to start dumping from. If not specified, start
dumping from root object.

=item -versions => $bool

If true, then version information is also dumped.

=item -attributes => $bool

If true, then attribute information is also dumped.

=item -children => $bool

Recurse into children. This is by default true.

=item -callback => $sub

A reference to a callback which can dump additional code. The
subroutine will get the following key-value pairs as arguments:

=over 4

=item -obj

The current object

=item -level

The current level

=item -indentstring

An indentation string

=back

The subroutine should return a string. See C<content_callback> in the
C<we_dump> script for an example.

=back

=cut

sub dump {
    my $self = shift;
    my %args = @_;
    my $root_object = (defined $args{-root}
		       ? $self->get_object(delete $args{-root})
		       : $self->root_object
		      );
    $self->_dump($root_object, 0, {}, %args);
}

sub _dump {
    my($self, $obj, $level, $seen, %args) = @_;

    my $s = " " x $level;

    if (!defined $obj) {
	warn "Undefined object detected in level=$level. Probably children/parent structure or the database is damaged.\n";
	return $s . "<undefined object>\n";
    }

    if ($seen->{$obj->Id}) {
	warn "Object with id already seen, no dumping from this point on...\n";
	return $s . "<seen object " . $obj->Id . ">\n";
    }
    $seen->{$obj->Id}++;

    my $shorten = sub {
	if (length $_[0] > $_[1]) {
	    substr($_[0], 0, $_[1])
	} else {
	    $_[0];
	}
    };
    my $langstr = sub {
	langstring($_[0], $self->Root->CurrentLang);
    };

    my $title = (defined $obj->Title
		 ? $shorten->($langstr->($obj->Title), defined $obj->Version_Number ? 35-length($obj->Version_Number)-3 : 35)
		 : "(no title)"
		) . (defined $obj->Version_Number ? " (".$obj->Version_Number.")" : "");

    $s .= sprintf "%s %-35s " . (" "x(13-$level)) . "%-8s %-8s %4d\n",
	($obj->is_sequence
	 ? "s"
	 : $obj->is_folder
	 ? "d"
	 : defined $obj->Version_Number
	 ? "v"
	 : "-"),
	$title,
	$shorten->($obj->Owner || "(none)", 8),
	defined $obj->TimeModified ? WE::Util::Date::short_readable_time(isodate2epoch($obj->TimeModified)) : "(none)",
	$obj->Id;
    if ($args{-versions}) {
	foreach my $sub_obj ($self->versions($obj)) {
	    $s .= $self->_dump($sub_obj, $level+1, $seen, %args);
	}
    }
    if ($args{-attributes}) {
	foreach my $key (sort keys %$obj) {
	    my $val =  $obj->{$key};
	    if (UNIVERSAL::can($val, "dump")) {
		$val = $val->dump;
	    }
	    if (!defined $val) { $val = "(undef)" }
	    $s .= " "x($level+1) . "|$key => $val" . "\n";
	}
	my @parent_ids = $self->parent_ids($obj);
	if (@parent_ids > 1) {
	    $s .= " "x($level+1) . "|Multiple parents => @parent_ids\n";
	}
    }
    if ($args{-callback}) {
	my $callback_s = $args{-callback}->(-obj => $obj, -level => $level,
					    -indentstring => " "x($level+1),
					   );
	$s .= $callback_s if defined $callback_s;
    }
    if ($obj->is_folder && (!exists $args{-children} || $args{-children})) {
	foreach my $sub_obj ($self->children($obj)) {
	    $s .= $self->_dump($sub_obj, $level+1, $seen, %args);
	}
    }
    $s;
}

=item depth($obj_id)

Get the minimum and maximum depth of the object. There are multiple
depths, because the object can be in multiple parents with different
depths.

    ($min_depth, $max_depth) = $objdb->depth($obj_id);

=cut

sub depth {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    $self->_depth($objid, 0, 0);
}

# XXX cycle detection? (see link)
sub _depth {
    my($self, $objid, $min_depth, $max_depth) = @_;
    my($add_min_depth, $add_max_depth);
    foreach my $p_id ($self->parent_ids($objid)) {
	my($p_min, $p_max) = $self->depth($p_id);
	if (!defined $add_min_depth || $p_min < $add_min_depth) {
	    $add_min_depth = $p_min;
	}
	if (!defined $add_max_depth || $p_max > $add_max_depth) {
	    $add_max_depth = $p_max;
	}
    }
    $add_min_depth = 0 if !defined $add_min_depth;
    $add_max_depth = 0 if !defined $add_max_depth;
    ($min_depth + $add_min_depth + 1, $max_depth + $add_max_depth + 1);
}

sub _get_next_version {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    my @versions = $self->versions($objid);
    my $max_major;
    my $max_minor;
    foreach my $v (@versions) {
	my($major, $minor);
	if (defined $v->Version_Number) {
	    ($major, $minor) = split /\./, $v->Version_Number;
	}
	if (!defined $max_major ||
	    (defined $major && ($major > $max_major ||
				($major == $max_major && $minor > $max_minor))
	    )
	   ) {
	    $max_major = $major;
	    $max_minor = $minor;
	}
    }
    if (!defined $max_major) {
	"1.0";
    } else {
	$max_minor++;
	$max_major . "." . $max_minor;
    }
}

=item PATH_SEP

The default path separator is "/".

=cut

use constant PATH_SEP => "/";

=item pathname2id($pathname [, $parent_obj])

Return the object id for the matching "pathname". There are no real
pathnames in the WE_Framework, so a dummy pathname is constructed by
the titles (english, if there are multiple). C<PATH_SEP> is used
as the path separator.

If C<$parent_obj> is given as a object, then the given pathname should
be only a partial path starting from this parent object.

Return C<undef> if no object could be found.

=cut

# XXX cycle test?
sub pathname2id {
    my($self, $name, $obj) = @_;
    $obj ||= $self->root_object;
    my(@c) = split PATH_SEP, $name;
    shift @c if (!defined $c[0] || $c[0] eq ''); # for "/"
 COMP_LOOP:
    while (my $component = shift @c) {
#	my $component_stripped = $component;
	# XXX is this ok? should I check whether the last component is a folder or not?
	# if (@c == 0) { # last component
	(my $component_stripped = $component) =~ s/\.[^.]+$//; # strip extension # XXX for last component (files) ?
#	}
	foreach my $c ($self->children($obj)) {
	    my $base = $c->Basename;
	    if (defined $base) {
		$base = _make_path_component($base);
		if ($component eq $base) {
		    $obj = $c;
		    next COMP_LOOP;
		}
	    } else {
		$base = langstring($c->Title);
		$base = _make_path_component($base);
		if ($component_stripped eq $base) {
		    $obj = $c;
		    next COMP_LOOP;
		}
	    }
	}
	return undef;
    }
    $obj->Id;
}

=item pathname($object_id [, $parent_obj, %args])

For the object C<$object_id>, the virtual pathname (as described in
pathname2id) is returned.

If C<$parent_obj> is given as a object, then the returned pathname is
only a partial path starting from this parent object.

Possible key-values for %args:

=over

=item -lang => $lang

Use the specified language C<$lang> rather than the default language
(en) for title composition.

=back

=cut

# XXX cycle test
# XXX should be more thought on (what about WE::Obj::Sites etc.)
sub pathname {
    my($self, $obj, $parent_obj, %args) = @_;
    $self->objectify_params($obj);
    my @parents = $self->parent_ids($obj->Id);
    my $ext = "";
    if ($obj->is_doc) {
	$ext = "." . $self->Root->ContentDB->extension($obj);
    }
    my $base = $obj->Basename;
    if (!defined $base) {
	my $langstring = (exists $args{-lang} 
			  ? langstring($obj->Title, $args{-lang})
			  : langstring($obj->Title)
			 );
	$base = _make_path_component($langstring) . $ext;
    }
    if (defined $parent_obj && $obj->Id eq $parent_obj->Id) {
	"";
    } elsif ($obj->isa("WE::Obj::Site")) {
	"/"
    } elsif (@parents) {
	my $parent_path = $self->pathname($parents[0], $parent_obj, %args);
	$parent_path .= PATH_SEP if $parent_path !~ m|^/?$|;
	$parent_path . $base;
    } else {
	"/$base";
    }
}

sub _make_path_component {
    my $name = shift;
    $name =~ s/@{[PATH_SEP]}/_/g;
    $name;
}

=item get_released_children($folder_id)

Return recursive all folders and released children of the given folder
C<$folder_id> as an array of objects.

=cut

sub get_released_children {
    my($objdb, $folder_id, %args) = @_;
    my @children = $objdb->children($folder_id);
    my @res;
    for my $o (@children) {
	if ($o->is_folder) {
	    push @res, $o;
	} else {
	    my $r = $objdb->get_released_object($o->Id, %args);
	    push @res, $r if defined $r;
	}
    }
    @res;
}

=item get_released_object($object_id)

Return the last released version for C<$object_id>. If there is no
released version yet, return C<undef>.

=cut

sub get_released_object {
    my($objdb, $obj_id, %args) = @_;
    my $obj = $objdb->get_object($obj_id);
    die "Can't get object with id $obj_id" if !$obj;
    my $releasable = $objdb->is_active_page($obj, %args);
    return undef if (!$releasable);
    if (defined $obj->Release_State && $obj->Release_State eq 'released') {
	return $obj;
    }
    foreach my $v_id (reverse $objdb->version_ids($obj_id)) {
	my $v = $objdb->get_object($v_id);
	if (defined $v->Release_State && $v->Release_State eq 'released') {
	    return $v;
	}
    }
    undef;
}

=item is_active_page($obj)

Return true if the object $obj is active, that is, the release state
is not I<inactive> and I<TimeOpen>/I<TimeExpire> does not apply.

=cut

sub is_active_page {
    my($objdb, $o, %args) = @_;
    $objdb->objectify_params($o);
    my $now = $args{-now};
    $now = epoch2isodate if !defined $now;
    my $active = $objdb->walk_up_preorder
	($o, sub {
	     my($obj_id) = @_;
	     my $o = $objdb->get_object($obj_id);
	     if (!$o) {
		 warn "Should never happen --- No object for id $obj_id found...";
		 return 1;
	     }
	     if (defined $o->Release_State && $o->Release_State eq 'inactive') {
		 $WE::DB::Obj::prune = 1; # cut off subtree
		 #warn "Inactive object found ($obj_id)\n";
		 return 0;
	     }

	     if ($o->is_time_restricted) {
		 $WE::DB::Obj::prune = 1; # cut off subtree
		 #warn "Time restricted object found ($obj_id)\n";
		 return 0;
	     }
	     1;
	 });
    $active;
}

sub count {
    my $self = shift;
    $self->connect_if_necessary
	(sub {
	     scalar keys(%{$self->{DB}}) - 2;
	 });
}

1;

__END__

=back

=head1 BUGS

For some methods, there are cycle test missing. Therefore it is
possible that methods cause endless loops, if links are causing cycle
loops! Please think before using C<link()>!

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>, L<WE::DB::ObjBase>.

=cut

