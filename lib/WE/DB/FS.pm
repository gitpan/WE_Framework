# -*- perl -*-

#
# $Id: FS.pm,v 1.6 2003/01/19 14:31:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE::DB::FS;
use base qw(WE::DB::ObjBase);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors(qw(MetaPrefix MetaSuffix RootDirectory
			     Except ExceptPat VCS
			     LockFile
			    ));

use Fcntl ':flock';
use File::Spec::Functions qw(:ALL);
use File::Basename;
use File::Copy (); # move and copy are also WE::DB::FS methods
use YAML ();
use WE::Util::MIME;
use WE::Util::Date;

sub new {
    my($class, $root, $rootdirectory, %args) = @_;
    my $self = {};
    bless $self, $class;

    $args{-locking}    = 0 unless defined $args{-locking};
    $args{-connect}    = 1 unless defined $args{-connect};

    $self->MetaPrefix(".meta.");
    $self->MetaSuffix("");
    $self->RootDirectory($rootdirectory);
    $self->VCS("RCS");
    $self->LockFile(".lock");

    $self->Root($root);
    $self->Connected(0);

    if ($args{-connect}) {
	$self->connect;
    }

    $self;
}

sub connect {
    my $self = shift;
    $self->_lock;
    $self->Connected(1);
}

sub connect_if_necessary {
    my($self, $sub) = @_;
    my $connected = $self->Connected;
    my $do_disconnect;
    if (!$connected) {
	$self->connect;
	$do_disconnect=1;
    }
    # XXX use wantarray!
    my $r;
    eval {
	($r) = $sub->();
    };
    my $err = $@;
    if ($do_disconnect) {
	$self->disconnect;
    }
    if ($err) {
	die $err;
    }
    $r;
}

sub disconnect {
    my $self = shift;
    if ($self->Connected) {
	$self->_unlock;
	$self->Connected(0);
    }
}

sub _lock {
    my $self = shift;
    my $lockfile = catfile($self->RootDirectory, $self->LockFile);
    open(LOCK, ">$lockfile") or die "Can't write to $lockfile: $!";
    flock(LOCK, LOCK_EX);
}

sub _unlock {
    my $self = shift;
    my $lockfile = catfile($self->RootDirectory, $self->LockFile);
    flock(LOCK, LOCK_UN);
    close LOCK;
}

sub children_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $dir = $self->_abs_filename($obj_id);
    my @children;
    if (opendir(DIR, $dir)) {
	my $f;
	while(defined($f = readdir DIR)) {
	    next if $f eq '.' || $f eq '..';
	    # XXX skip expect ...
	    next if $f eq '.lock'; # XXX use LockFile...
	    next if $f =~ /^\.meta/; # XXX use MetaPrefix/Suffix...
	    next if $f eq 'db' && $self->is_root_object($obj_id); # XXX exclude db
	    next if $f =~ /^(RCS|CVS|\.svn)$/; # XXX should be determined from $self->VCS
	    push @children, $obj_id . "/" . $f;
	}
	closedir DIR;
    } else {
	#warn "Can't open $dir: $!";
    }
    @children;
}

sub parent_ids {
    my($self, $obj_id) = @_;
    my @ret;
    $self->idify_params($obj_id);
    if (!$self->is_root_object($obj_id)) {
	@ret = dirname($obj_id);
    }
    @ret; # XXX does not handle symlinks yet
}

sub version_ids {
    my($self, $obj_id) = @_;
    my @ret;
    return @ret if (!defined $self->VCS);
    $self->idify_params($obj_id);
    my $vcs = $self->_get_vcs_object($obj_id);
    if (defined $vcs) {
	my $base = $self->_filename($obj_id);
	for my $version ($vcs->versions) {
	    push @ret, "version:" . $version->version . ";" . $base;
	}
    }
    @ret;
}

# different signature from WE::DB::Obj
sub _next_id {
    my($self, $parent_id, $basename) = @_;
    if (!defined $basename || $basename eq '') {
	$basename = "0000";
    } else {
	my $file = $self->_abs_filename("$parent_id/$basename");
	if (-e $file) {
	    if ($basename !~ /_\d{4}$/) {
		$basename .= "_0000";
	    }
	} else {
	    my $meta_file = $self->_abs_meta_filename("$parent_id/$basename");
	    if (-e $meta_file) {
		if ($basename !~ /_\d{4}$/) {
		    $basename .= "_0000";
		}
	    }
	}
    }
    while(1) {
	my $file = $self->_abs_filename("$parent_id/$basename");
	if (!-e $file) {
	    my $meta_file = $self->_abs_meta_filename("$parent_id/$basename");
	    if (!-e $meta_file) {
		return "$parent_id/$basename";
	    }
	}
	$basename++;
    }
}

sub _store_meta_object {
    my($self, $obj) = @_;
    my $meta_file = $self->_abs_meta_filename($obj->Id);
    open(META, ">$meta_file") or die "Can't write $meta_file: $!";
    print META YAML::Dump($obj);
    close META;
}

sub _get_vcs_object {
    my($self, $obj_id, $version_number, $non_meta) = @_;
    require VCS;
    my $file = ($non_meta ? $self->_abs_filename($obj_id) : $self->_abs_meta_filename($obj_id));
    if ($self->VCS eq 'RCS') {
	my $rcs_dir = catfile(dirname($file), "RCS");
	if (!-e $rcs_dir) {
	    return undef;
	}
	if (!-e catfile($rcs_dir, basename($file).",v")) {
	    return undef;
	}
    }
    my $vcs_url = "vcs://localhost/VCS::" . ucfirst(lc($self->VCS)) . $file;
    %VCS::Rcs::LOG_CACHE = (); # XXX
    if (defined $version_number) {
	VCS::Version->new($vcs_url . "/" . $version_number);
    } else {
	VCS::File->new($vcs_url);
    }
}

sub _get_meta_object {
    my($self, $id) = @_;
    my $meta_file;
    my $version_number;
    my $version_info = [];
    my $version_obj;
    my $ret;
    if ($self->is_version($id, $version_info)) {
	$version_number = $version_info->[0];
	$version_obj = $self->_get_vcs_object($id, $version_number);
	if ($version_obj) {
	    my $buf = $version_obj->text;
	    $ret = YAML::Load($buf);
	} else {
	    warn "Can't get VCS object for $id, version $version_number";
	}
    } else {
	$meta_file = $self->_abs_meta_filename($id);

	if (open(META, $meta_file)) {
	    local $/ = undef;
	    my $buf = <META>;
	    close META;
	    $ret = YAML::Load($buf);
	}
    }

    if (!$ret) {
	my $file = $self->_abs_filename($id);
	if      ($id eq 'file:') { # fake root object
	    $ret = WE::Obj::Site->new;
	    $ret->Id($id);
	    $ret->Title("Root of the site");
	} elsif (-d $file) {
	    $ret = WE::Obj::Folder->new;
	    $ret->Id($id);
	} elsif (-f $file) {
	    $ret = WE::Obj::Doc->new;
	    $ret->Id($id);
	} else {
	    #warn "Neither can open $meta_file nor $file: $!";
	}
    }

    if ($version_obj) {
	# Version pseudo attributes (unchangeable!)
	$ret->Version_Number($version_number);
	$ret->Version_Owner($ret->Owner);
	$ret->Version_Comment($version_obj->reason);
	$ret->Version_Parent($ret->Id);
	$ret->Id("version:$version_number;" . $self->_filename($ret->Id));
    }

    $ret;
}

sub _filename {
    my($self, $id) = @_;
    my($type, $rest) = $id =~ /^([^:]+):(.*)/; # "file:/path/to/file"
    my $base;
    if ($type eq 'file') {
	$base = $rest;
    } elsif ($type eq 'version') {
	my($ver, $file) = $rest =~ /^([^;]+);(.*)/; # "version:1.2,/path/to/file"
	$base = $file;
    } else {
	die "Unrecognized type <$type> from id <$id>";
    }
    $base;
}

sub _abs_filename {
    my($self, $id) = @_;
    canonpath(catfile($self->RootDirectory, $self->_filename($id)));
}

sub _abs_meta_filename {
    my($self, $id) = @_;
    my $file = $self->_filename($id);
    canonpath(catfile($self->RootDirectory,
		      dirname($file),
		      join("", $self->MetaPrefix, basename($file), $self->MetaSuffix)));
}

sub insert_doc {
    my($self, %args) = @_;
    my $doc = WE::Obj::Doc->new;
    # XXX permission manager
    my $content = delete $args{-content};
    my $file    = delete $args{-file};
    my $parent  = delete $args{-parent};
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	$doc->{ucfirst(substr($k,1))} = $v;
    }
    if (defined $file) {
	$doc->{ContentType} = get_mime_type_by_filename($file) if !$doc->{ContentType};
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
    $self->_store_content($doc, $content);
    $doc;
}

sub insert_folder {
    my($self, %args) = @_;
    my $folder = WE::Obj::Folder->new;
    # XXX permission manager
    my $parent = delete $args{-parent};
    while(my($k,$v) = each %args) {
	die "Option does not start with a dash: $k" if $k !~ /^-/;
	$folder->{ucfirst(substr($k,1))} = $v;
    }

    $folder = $self->insert($folder, -parent => $parent);
    $folder;
}

sub insert {
    my($self, $obj, %args) = @_;

    $self->connect_if_necessary(sub {
        my $parent  = delete $args{-parent};
	if (!defined $parent) {
	    die "The -parent option is missing";
	}
	$self->idify_params($parent);
	my $id = $self->_next_id($parent, $obj->{Basename});

	my $parent_obj = $self->get_object($parent);
	if (!$parent_obj->isa("WE::Obj::FolderObj")) {
	    die "The object with the id $parent is not a FolderObj, but a " . ref $parent_obj . ". Objects can only be inserted in folders.";
	}
	if (!$parent_obj->object_is_insertable($obj)) {
	    die "The object type " . ref($obj) . " is not allowed in " . ref($parent_obj) . ". The only allowed object types are: " . join(", ", @{ $parent_obj->insertable_types });
	}

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

	$self->_store_meta_object($obj);

	if ($obj->is_folder) {
	    my $dir = $self->_abs_filename($obj->Id);
	    mkdir $dir, 0775; # XXX mode, check etc.
	}

	# update names, links ...
	if ($self->Root->NameDB) {
	    $self->Root->NameDB->update([$obj],[]);
	}
    });

    $obj;
}

sub get_object {
    my($self, $obj_id) = @_;
    $self->_get_meta_object($obj_id);
}

sub root_object {
    my($self) = @_;
    $self->get_object("file:");
}

sub is_root_object {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    $objid eq 'file:';
}

sub is_version {
    my($self, $objid, $ver_info_ref) = @_;
    if ($objid =~ /^version:([^;]+);(.*)/) {
	if ($ver_info_ref) {
	    @$ver_info_ref = ($1, $2);
	}
	1;
    } else {
	0;
    }
}

sub content {
    my($self, $objid) = @_;

    my $obj;
    if (ref $objid) {
	$obj = $objid;
	$objid = $obj->Id;
    } else {
	$obj = $self->get_object($objid);
    }

    my $file = $self->_abs_filename($objid);
    if (-d $file) {
	die "Can't get content for object <$objid>";
    }

    my $content;
    my $version_info = [];
    if ($self->is_version($objid, $version_info)) {
	$content = $self->_get_vcs_object($objid, $version_info->[0], 'non-meta')->text;
    } else {
	open(F, $file) or die "Can't get content from file <$file> for object <$objid>: $!";
	local $/ = undef;
	$content = <F>;
	close F;
    }
    $content;
}

*get_content = \&content;

sub _store_content {
    my($self, $obj_id, $content) = @_;
    $self->idify_params($obj_id);
    my $file = $self->_abs_filename($obj_id);
    open(F, ">$file") or die "Can't write content for object <$obj_id>: $!";
    print F $content;
    close F;
}

sub remove {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    $self->connect_if_necessary
	(sub {
	     my $file      = $self->_abs_filename($obj_id);
	     my $meta_file = $self->_abs_meta_filename($obj_id);
	     my $o         = $self->get_object($obj_id);

	     # unlink children
	     if ($o->is_folder) {
		 foreach my $child_id ($self->children_ids($obj_id)) {
		     # XXX can't unlink yet
		     $self->remove($child_id);
		 }
	     }

	     # delete everything in name database
	     if ($self->Root->NameDB) {
		 $self->Root->NameDB->update([], [$o]);
	     }

	     # delete physical object
	     if (-d $file) {
		 rmdir $file;
	     } else {
		 unlink $file;
	     }
	     unlink $meta_file;

#  	     # delete remaining links
#  	     my @obj_ids = $self->find_links($obj_id);
#  	     foreach my $id (@obj_ids) {
#  		 my $stored_obj = $self->_get_stored_obj($id);
#  		 $self->_remove_from_link_array($obj_id, $stored_obj);
#  		 $self->_store_stored_obj($stored_obj);
#  	     }

	 });
}

sub replace_object {
    my($self, $obj) = @_;
    # XXX permission manager
    my $old_obj = $self->_get_meta_object($obj->Id);
    die "Can't get meta object from id " . $obj->Id if !$old_obj;
    $obj->TimeModified(epoch2isodate());
    $obj->Dirty(1);
    $obj->DirtyAttributes(1);
    $self->_store_meta_object($obj);

    # update names, links ...
    my $namedb = $self->Root->NameDB;
    if ($namedb) {
	$namedb->update([$obj],[$old_obj]);
    }

    $obj;
}

sub replace_content {
    my($self, $objid, $new_content) = @_;
    $self->idify_params($objid);
    my $obj = $self->get_object($objid) || die "Can't get object for id $objid";
    $obj->TimeModified(epoch2isodate());
    $obj->Dirty(1);
    $obj->DirtyContent(1);
    $self->_store_meta_object($obj);
    $self->_store_content($objid, $new_content);
    $obj;
}

sub exists {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    defined $self->_get_meta_object($obj_id);
}

# Different return value: return object id for moved object
sub move {
    my($self, $objid, $parentid, %args) = @_;
    $self->idify_params($objid);
#      if (!defined $parentid) {
#  	$parentid = ($self->parent_ids($objid))[0];
#      }
#      $self->idify_params($parentid);

    my $destination = delete $args{-destination};
    if (!defined $destination) {
	$destination = delete $args{-target}; # Alias for -destination
    }
    my $after  = delete $args{-after};
    if (defined $after) {
	die "-after NYI";
    }
    my $before = delete $args{-before};
    if (defined $before) {
	die "-before NYI";
    }
    my $to     = delete $args{-to};
    if (defined $to) {
	die "-to NYI";
    }
    if (defined $destination) {
	$self->idify_params($destination);
	my $src_file = $self->_abs_filename($objid);
	my $src_meta_file = $self->_abs_meta_filename($objid);
	my $dest_dir = $self->_abs_filename($destination);
	if (!-d $dest_dir) {
	    die "Destination is not a directory";
	}
	my $dest_id = $self->_next_id($destination, basename($src_file));
	my $dest_file = $self->_abs_filename($dest_id);
	my $dest_meta_file = $self->_abs_meta_filename($dest_id);
	File::Copy::move($src_file, $dest_file);
	File::Copy::move($src_meta_file, $dest_meta_file);
	$self->_repair_meta_data($dest_id);
	$self->walk($dest_id, sub { $self->_repair_meta_data($_[0]) });
	$dest_id;
    } else {
	die "Nowhere to move. Please specify either -destination, -before or -after";
    }
}

sub copy {
    my($self, $object_id, $target_id, %args) = @_;
    $self->_copy($object_id, -parent => $target_id, %args);
}

sub _copy {
    my($self, $object_id, %args) = @_;
    $self->idify_params($object_id);
    my $obj = $self->get_object($object_id);
    require Carp, Carp::croak("Can't find object with id $object_id") if !$obj;

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
#	}
	$self->$insert_meth($clone_obj, %insert_args);
	$self->replace_content($clone_obj, $content);
	$clone_obj;
    } else { # copy folder
	my $clone_obj = $obj->clone;
#XXX	if (grep($_ eq $target_id, $self->parent_ids($object_id))) {
#	    # XXX NYI: change title to "Copy of ..." (lang-dependent)
#	}
	my @ret;
	$self->$insert_meth($clone_obj, %insert_args);
	push @ret, $clone_obj;
	if (!exists $args{-recursive} || $args{-recursive}) {
	    foreach my $child_id ($self->children_ids($object_id)) {
		if (exists $insert_args{-parent}) {
		    $insert_args{-parent} = $clone_obj->Id;
		} else {
		    $insert_args{-versionparent} = $clone_obj->Id;
		}
		push @ret, $self->_copy($child_id, %insert_args);
	    }
	}
	@ret;
    }
}

sub _repair_meta_data {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->_get_meta_object($obj_id);
    my $changed = 0;
    if ($obj_id ne $o->Id) {
	$o->Id($obj_id);
	$changed++;
    }
    if ($changed) {
	$self->_store_meta_object($o);
    }
}

sub ci {
    my($self, $obj_id, %args) = @_;
    $self->idify_params($obj_id);
    if (defined $args{-version}) {
	$args{-number} = delete $args{-version};
    }
    if (defined $args{-comment}) {
	$args{-log} = delete $args{-comment};
    }
    my $trimold = delete $args{-trimold};
    my @ret;

    if ($self->VCS eq 'RCS') {
	my @ci_args;
	if (defined $args{-number}) {
	    push @ci_args, "-l" . $args{-number};
	} else {
	    push @ci_args, "-l";
	}
	if (defined $args{-log}) {
	    push @ci_args, "-m" . $args{-log}, "-f";
	}
	my $file = $self->_abs_filename($obj_id);
	my $meta_file = $self->_abs_meta_filename($obj_id);

	my $rcs_dir = catfile(dirname($meta_file), "RCS");
	if (!-d $rcs_dir) {
	    mkdir $rcs_dir, 0775; # XXX check; mode
	}

	my($meta_ver, $ver, $_log);

	my $parse_for_versions = sub {
	    my $fh = shift;
	    $_log = "";
	    while(<$fh>) {
		$_log .= $_;
		if (/new revision:\s+([\d.]+)/) {
		    return $1;
		} elsif (/initial revision:\s+([\d.]+)/) {
		    return $1;
		} elsif (/file is unchanged; reverting to previous revision\s+([\d.]+)/) {
		    return $1;
		}
	    }
	    undef;
	};

	open(CI, "-|") or do {
	    open(STDIN, "<" . File::Spec->devnull) or die $!;
	    open(STDERR, ">&STDOUT") or die $!;
	    exec("ci", @ci_args, $meta_file);
	    die $!;
	};
	$meta_ver = $parse_for_versions->(\*CI);
	close CI;
	if (!defined $meta_ver) {
	    warn "Can't get version for $meta_file. Log is <$_log>";
	}

	if (!-d $file) {
	    open(CI, "-|") or do {
		open(STDIN, "<" . File::Spec->devnull) or die $!;
		open(STDERR, ">&STDOUT") or die $!;
		exec("ci", @ci_args, $file);
		die $!;
	    };
	    $ver = $parse_for_versions->(\*CI);
	    close CI;
	    if (!defined $ver) {
		warn "Can't get version for $file. Log is <$_log>";
	    } else {
		if ($ver ne $meta_ver) {
		    warn "Versions for file and meta file differ: $ver != $meta_ver";
		}
	    }

	    push @ret, "version:$meta_ver;" . $self->_filename($obj_id);
	}

    } else {
	die "VCS type " . $self->VCS . " not yet implemented";
    }

    if ($trimold) {
#XXX not yet implemented:	$self->trim_old_versions($obj_id, -trimold => $trimold);
    }

    $self->_undirty($obj_id);

    if (wantarray) {
	map { $self->get_object($_) } @ret;
    } else {
	$self->get_object($ret[0]);
    }
}

sub co {
    my($self, $obj_id, %args) = @_;
    $self->idify_params($obj_id);
    if (defined $args{-version}) {
	$args{-number} = delete $args{-version};
    }
    my $v_obj;
    if (!defined $args{-number}) {
	my @v_id = $self->version_ids($obj_id);
	if (!@v_id) {
	    die "There are no versions available for object $obj_id";
	}
	$v_obj = $self->get_object($v_id[-1]);
    }
    if (!$v_obj) {
	foreach my $v ($self->versions($obj_id)) {
	    if ($v->Version_Number eq $args{-number}) {
		$v_obj = $v;
		last;
	    }
	}
    }
    if (!$v_obj) {
	die "Can't find version $args{-number} for object $obj_id";
    }

    if ($self->VCS eq 'RCS') {
	my $file = $self->_abs_filename($obj_id);
	my $meta_file = $self->_abs_meta_filename($obj_id);
	# XXX redirect stderr, check error messages
	system("rcs", "-u", $file); # unlock
	my @co_args = ("-f", "-l");
	if (defined $args{-number}) {
	    push @co_args, "-r".$args{-number};
	}
	system("co", @co_args, $file);
	system("co", @co_args, $meta_file);
    } else {
	die "VCS type " . $self->VCS . " not yet implemented";
    }

    $self->get_object($v_obj->Version_Parent);
}

# XXX does not use symlink information for multiple parents
sub depth {
    my($self, $objid) = @_;
    $self->idify_params($objid);
    my $file = $self->_filename($objid);
    # XXX canonify path?
    my $depth = $file =~ tr|/|/|;
    ($depth+1, $depth+1);
}

# XXX does not handle version ids (I think)
sub pathname {
    my($self, $obj, $parent_obj) = @_;
    $self->idify_params($obj, $parent_obj);
    my $pathname = $obj;
    if (defined $parent_obj) {
	($pathname = $obj) =~ s/^\Q$parent_obj\///;
    } else {
	$pathname =~ s/^file://;
    }
    if ($pathname eq '') {
	$pathname = '/';
    }
    $pathname;
}

sub pathname2id {
    my($self, $name, $parent) = @_;
    $self->idify_params($parent);
    my $id = "file:" . ($name eq '/' ? "" : $name);
    if (!$self->exists($id)) {
	undef;
    } else {
	$id;
    }
}

sub search_fulltext {
    my($self, $term, %args) = @_;

    my $obj = (defined $args{-scope}
	       ? $self->get_object($args{-scope})
	       : $self->root_object);
    if (!$obj) {
	die "Cannot get scoped object";
    }

    if (!$args{-regexp}) {
	$term = "\Q$term";
    }
    if (!$args{-casesensitive}) {
	$term = "(?i)$term";
    }

    delete $args{-scope};
    $self->_search_fulltext($obj, $term, %args);
}

sub _search_fulltext {
    my($self, $obj, $term, %args) = @_;
    my @res_ids;
    if ($obj->is_folder) {
	foreach my $s_obj ($self->children($obj)) {
	    push @res_ids, $self->_search_fulltext($s_obj, $term, %args);
	}
    } elsif ($obj->is_doc) {
	push @res_ids, $obj->Id
	    if grep { $_ =~ /$term/s } $self->get_content($obj->Id);
    }
    @res_ids;
}

sub filename {
    my($self, $obj_id) = @_;
    $self->_abs_filename($obj_id);
}

package WE::DB::FS::ContentDB; # fake package

use vars qw(@ISA $AUTOLOAD);

@ISA = 'WE::DB::FS';

sub AUTOLOAD {
    shift->{FS}->$AUTOLOAD(@_);
}

sub new {
    my($class, $fsdb) = @_;
    bless {FS => $fsdb}, $class;
}

1;

__END__

=head1 NAME

WE::DB::FS - filesystem implementation of WE::DB

=head1 SYNOPSIS

    $objdb = WE::DB::FS->new($root, $rootdirectory);
    $objdb = $root->ObjDB

=head1 DESCRIPTION

This is a filesystem implementation of C<WE::DB>. Please see
L<WE::DB::Obj> for a description of available methods. Note that not
all C<WE::DB::Obj> methods are implemented yet.

=cut
