# -*- perl -*-

#
# $Id: Content.pm,v 1.8 2004/05/11 13:05:13 eserte Exp $
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

package WE::DB::Content;

=head1 NAME

WE::DB::Content - the content database for the web.editor

=head1 SYNOPSIS

    $content_db = new WE::DB::Content($root, $content_db_directory);

=head1 DESCRIPTION

The content database contains the real contents (HTML, text, images)
of the objects in the object database.

=cut

use base qw/Class::Accessor/;

__PACKAGE__->mk_accessors(qw/Root Directory/);

use strict;
use vars qw($VERSION $VERBOSE);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use WE::Util::MIME qw(%mime_types);

=head2 CONSTRUCTOR WE::DB::Content->new($root, $directory);

The Content database is usually created in the C<WE::DB> object.

=cut

sub new {
    my($class, $root, $directory) = @_;
    my $self = {};
    bless $self, $class;
    $self->Root($root);
    $self->Directory($directory);
    $self;
}

=head2 METHODS

=over 4

=item init

Initializes the content database. This means that the directory
holding the content files is created.

=cut

sub init {
    my($self) = @_;

    if (!defined $self->Directory) {
	die "The directory is not defined!";
    }

    if (!-d $self->Directory) {
	require File::Path;
	File::Path::mkpath([$self->Directory], 0, 0770);
    }

    if (!-w $self->Directory) {
	die "Can't write to directory @{[ $self->Directory ]}";
    }
}

=item store($objid, $content)

Store the $content (which is a string) for object with id $objid.

=cut

sub store {
    my($self, $obj, $content) = @_;
    my $file = $self->filename($obj);
    my $tempfile = "$file~";
    if (!defined $content) {
	unlink $file;
    } else {
	my(@oldstat) = stat $file;
	open(C, ">$tempfile") or die "Can't write to file $tempfile: $!";
	print C $content;
	close C;
	if (@oldstat) {
	    eval {
		chown -1, $oldstat[5], $tempfile;
	    };
	    eval {
		chown $oldstat[4], -1, $tempfile;
	    };
	    chmod $oldstat[2] & 07777, $tempfile;
	}
	rename $tempfile, $file or die "Can't rename $tempfile to $file: $!";
    }
}

=item get_content($objid)

Get the content for object with id $objid. The content is returned as
a string.

=cut

sub get_content {
    my($self, $obj) = @_;
    my $file = $self->filename($obj);
    open(C, $file) or die "Can't read file $file: $!";
    local $/ = undef;
    my $content = <C>;
    close C;
    $content;
}

=item remove($objid)

Remove the content for object with id $objid.

=cut

sub remove {
    my($self, $obj) = @_;
    my $file = $self->filename($obj);
    unlink $file;
}

=item copy($from_objid, $to_objid)

Copy the content from $from_objid to $to_objid. This may be
implemented efficiently using OS copy.

=cut

sub copy {
    my($self, $from_objid, $to_objid) = @_;
    if (eval 'require File::Copy; 1') {
	my $from_filename = $self->filename($from_objid);
	my $to_filename   = $self->filename($to_objid);
	File::Copy::copy($from_filename, $to_filename);
    } else {
	my $content = $self->get_content($from_objid);
	$self->store($to_objid, $content);
    }
}

=item filename($objid)

Return the absolute filename for the object with id $objid (or supply the
WE::Obj). Usually, the content should not be accessed directly. But we
are Perl, so it is possible nevertheless.

=cut

sub filename {
    my($self, $obj) = @_;
    my($ext, $id);
    if (!UNIVERSAL::isa($obj, "WE::Obj")) {
	$id = $obj;
	$obj = $self->Root->ObjDB->get_object($id);
	die "Can't get object for id $id" if !$obj;
    }
    $id = $obj->Id;
    $id =~ s/\D/_/g; # only safe characters
    $ext = _extension($obj->ContentType);
    $self->Directory . "/" . $id . "." . $ext;
}

=item extension($obj)

Return the extension of the supplied C<WE::Obj> object.

=cut

sub extension {
    my($self, $obj) = @_;
    _extension($obj->ContentType);
}

# XXX move real implementation to Util module!
sub _extension {
    my($mimetype) = @_;
    my $ext = exists $mime_types{$mimetype} ? $mime_types{$mimetype}->[0] : undef;
    if (!defined $ext) {
	# fallback...
	if (eval 'require MIME::Types; 1') {
	    my @ext = MIME::Types::by_mediatype($mimetype);
	    $ext = $ext[0]->[0] if @ext;
	}
    }
    if (!defined $ext) {
	warn "Cannot get extension for mime type $mimetype" if $VERBOSE;
	$ext = "bin";
    }
    $ext;
}

=item get_mime_type_by_filename($filename)

Return the MIME type (e.g. C<text/plain>) of the supplied file.

=cut

sub get_mime_type_by_filename {
    my($self, $filename) = @_;
    WE::Util::MIME::get_mime_type_by_filename($filename);
}

=item delete_db_contents

Delete all database contents

=cut

sub delete_db_contents {
    my $self = shift;
    return unless defined $self->Directory || !-d $self->Directory;
    opendir(D, $self->Directory);
    while(my $f = readdir D) {
	next if $f =~ /^\.\.?$/;
	unlink $self->Directory ."/". $f or warn "Can't delete $f: $!";
    }
    closedir D;
}

=item search_fulltext($term, %args)

Search the term in the content database and return a list of object
ids. Further options are:

=over 4

=item -scope => $id

Id of the scope for the search.

=item -lang => $lang

Restrict search to the specified language. Otherwise all languages are
used. NYI.

=item -casesensitive => $bool

True, if the search should be case sensitive.

=item -regexp => $bool

True, if the search term is a regular expression.

=back

=cut

sub search_fulltext {
    my($self, $term, %args) = @_;

    my $obj = (defined $args{-scope}
	       ? $self->Root->ObjDB->get_object($args{-scope})
	       : $self->Root->ObjDB->root_object);
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
	foreach my $s_obj ($self->Root->ObjDB->children($obj)) {
	    push @res_ids, $self->_search_fulltext($s_obj, $term, %args);
	}
    } elsif ($obj->is_doc) {
	push @res_ids, $obj->Id
	    if grep { $_ =~ /$term/s } $self->get_content($obj->Id);
    }
    @res_ids;
}

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

