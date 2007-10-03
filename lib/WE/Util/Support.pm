# -*- perl -*-

#
# $Id: Support.pm,v 1.10 2006/04/18 21:39:44 eserte Exp $
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

package WE::Util::Support;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE::Util::Support - support functions for the WE::DB framework

=head1 SYNOPSIS

    use WE::Util::Support;

=head1 DESCRIPTION

=cut

package WE::DB::Obj;
use WE::DB::Obj;

# Backward compatibility...
if (!WE::DB::Obj->can('idify_params')) {
    #warn "Define alias idify_params";
    *idify_params = sub { shift->_idify_params(@_) };
}

=head2 METHODS in the WE::DB::Obj package

=over 4

=item create_folder_tree(...)

Create a folder tree from file or string.

Options are:

=over 4

=item -string => $string

The string with the folder information.

=item -file => $file

A file with the folder information. Either -string or -file have to exist.

=item -rootid => $rootid

The root object id to put the top-most folder in. If missing, then the
root obejct of the database will be used.

=item -standardargs => { ... }

Add standard arguments for each created object. The standard arguments
will be overwritten by the arguments in the folder information
string/file.

=back

The file or string should contain a list of attributes, prefixed with
a "-" and their values. All keys and values should be separated by
spaces. To mask spaces in attribute values, just use double quotes.
The folder structure is controlled by indentation, that is, top-level
folder are not indented, the second-level folders have one space
indentation and so on.

For the B<Title> attribute, there is an exception to handle language
dependent strings: the first two letters should form the ISO 638 code
for the language, followed by a colon, followed by the language
dependent string. You can specify as many language strings as you
like. If you do not need language dependent Title strings, then just
use this attribute as the others.

Examples for B<Title>:

    -Title "language independent string" -Name a_name
    -Title "en:english" "de:german" "it:italian" -Name b_name

=cut

sub create_folder_tree {
    my($self, %args) = @_;
    my $string = $args{'-string'};
    if (!defined $string) {
	if (exists $args{-file}) {
	    open(F, $args{-file}) or die "Can't open $args{-file}: $!";
	    local $/ = undef;
	    $string = <F>;
	    close F;
	} else {
	    die "Either -file or -string must be given";
	}
    }
    my $rootid = $args{'-rootid'};
    if (!defined $rootid) {
	$rootid = $self->root_object->Id;
    }
    my %std_args = ($args{'-standardargs'} ? %{$args{'-standardargs'}} : ());

    # first pass: just check the indentation
    my $last_indent = 0;
    foreach my $line (split /\n/, $string) {
	$line =~ /^(\s*)/;
	my $indent = length $1;
	if ($indent > $last_indent+1) {
	    die "Indentation error in line <$line>\n";
	}
	$last_indent = $indent;
    }

    # second pass: do the right thing
    require Text::ParseWords;
    my @indent2objid;
    $indent2objid[0] = $rootid;
    foreach my $line (split /\n/, $string) {
	$line =~ s/^(\s*)//;
	my $indent = length $1;
	my $parentid = $indent2objid[$indent];
	if (!defined $parentid) {
	    die "Parse error in line $line? Check the indentation!\n";
	}
	my %token;
	my(@token) = Text::ParseWords::shellwords($line);

	# special handling for languagestrings in Title:
	for(my $i=0; $i<=$#token; ) {
	    my($key, $val) = @token[$i, $i+1];
	    if ($key eq '-Title') {
		if ($val =~ /^(..):(.*)/) {
		    my($lang, $string) = ($1,$2);
		    require WE::Util::LangString;
		    my $ls = WE::Util::LangString->new;
		    $ls->{$lang} = $string;
		    $i+=2;
		    while (1) {
			$val = $token[$i];
			if (!defined $val || $val =~ /^-/) {
			    # next option/no option => write langstring
			    $token{$key} = $ls;
			    last;
			} elsif ($val =~ /^(..):(.*)/) {
			    my($lang, $string) = ($1,$2);
			    $ls->{$lang} = $string;
			    $i++;
			} else {
			    die "Parse error in line $line: either language string or new option expected, but got $val";
			}
		    }
		} else {
		    $token{$key} = $val;
		    $i+=2;
		}
	    } else {
		$token{$key} = $val;
		$i+=2;
	    }
	}

	my %args = (%std_args, %token);
	$args{'-parent'} = $parentid;
	my $fldr = $self->insert_folder(%args); # XXX handle langstrings?
	my $newobjid = $fldr->Id;
	$indent2objid[$indent+1] = $newobjid;
    }
}

=item change_order($p_id, \@child_ids)

For the parent collection C<$p_id> the children will be sorted
according to the array reference C<@child_ids>. Children of C<$p_id>
which are not in C<@child_ids> will be put to the back. Throws an
error if one of C<@child_ids> is not a child of C<$p_id>.

=cut

sub change_order {
    my($self, $p_id, $child_ids_ref) = @_;
    my(@child_ids) = @$child_ids_ref;
    $self->idify_params($p_id, @child_ids);

    # The connect is here used as a locking mechanism.
    $self->connect_if_necessary
	(sub {
	     my $p_stored_obj = $self->_get_stored_obj($p_id);
	     die "Can't get stored object for <$p_id>" if !$p_stored_obj;
	     # first check whether the children are really the children:
	     my @real_children = $self->children_ids($p_id);
	     my(%real_children) = map { ($_=>1) } @real_children;
	     foreach my $c_id (@child_ids) {
		 if (!exists $real_children{$c_id}) {
		     die "The object <$c_id> is not child of <$p_id>!";
		 }
	     }
	     my @new_child_list = @child_ids;
	     foreach (@child_ids) { delete $real_children{$_} }
	     # put missing ids to the back
	     if (keys %real_children) {
		 warn "The following ids are unhandled by change_order: @{[ keys %real_children ]}";
		 # iterate over array to preserver old order
		 foreach (@real_children) {
		     if (exists $real_children{$_}) {
			 push @new_child_list, $_;
			 delete $real_children{$_};
		     }
		 }
		 if (keys %real_children) {
		     die "Strange! There are still some keys unhandled: @{[ keys %real_children ]}";
		 }
	     }

	     $p_stored_obj->[WE::DB::Obj::CHILDREN] = \@new_child_list;
	     $self->_store_stored_obj($p_stored_obj);
	 });
}

=item get_position_array($obj_id, [%args])

For a given object C<$obj_id>, return an array with the positions of
this object in its parent, and the positions of all predecessors.

The following options are recognized for C<%args>:

=over 4

=item -base => C<$base>

The positions are by default 0-based, but can be changed with the
optional argument C<$base>.

=item -filter => C<$sub>

Specify an optional filter for the recursion process. The filter
options should be a reference to a subroutine. This subroutine is
called with two arguments: the object database reference and the id of
an object to test. If the object should be included into the position
counting, then 1 should be returned, otherwise 0.

=item -indexdoc => C<$bool>

If true, then the IndexDoc attribute is used for determining the
document position.

=back

Note that only the first parent is used, if there are objects with
multiple parents.

=cut

sub get_position_array {
    my($self, $obj_id, %args) = @_;
    my $base = defined $args{-base} ? $args{-base} : 0;
    my $filter = $args{-filter};
    $self->idify_params($obj_id);
    my($p_id) = ($self->parent_ids($obj_id))[0];
    return () if !defined $p_id;
    my(@children_ids) = $self->children_ids($p_id);

    if ($args{'-indexdoc'}) {
	my $p_obj = $self->get_object($p_id);
	if (!$p_obj) {
	    die "Can't get object for id $p_id";
	}
	if ($p_obj->{IndexDoc} && $p_obj->{IndexDoc} == $obj_id) {
	    return $self->get_position_array($p_id, %args);
	}
    }

    my $this_pos;
    my $pos = 0;
    for my $c_id (@children_ids) {
	if ($filter && !$filter->($self, $c_id)) {
	    next;
	}
	if ($c_id eq $obj_id) {
	    $this_pos = $pos + $base;
	    last;
	}
	$pos++;
    }
    if (!defined $this_pos) {
	my $err = "Strange: can't find object <$obj_id> in the children collection of its parent <$p_id>.";
	if ($filter) {
	    $err .= "\nMaybe the filter was to strict?";
	}
	die $err;
    }
    ($self->get_position_array($p_id, -filter => $filter, -base => $base), $this_pos);
}

=item check_integrity

Return a C<WE::DB::Obj::Fsck> object with lists of inconsistencies in
the C<WE::DB::Obj> database.

=cut

sub check_integrity {
    my $self = shift;
    my $contentdb = shift;

    my @undef_values;
    my @broken_values;
    my @not_existing_children;
    my @not_existing_parents;
    my @not_existing_versions;
    my @not_referenced;
    my @wrong_ids;
    my @child_parent_mismatches;
    my @doc_object_without_content;

    my $root_object_missing = 0;

    my %referenced;

    my $root_obj = $self->root_object;
    if (!$root_obj) {
	# This is fatal, don't do any other checks
	$root_object_missing = 1;
	goto RETURN;
    } else {
	$referenced{$root_obj->Id} = [];
    }

    $self->connect_if_necessary(sub {
	 my @keys = grep { !/^_/ } keys %{ $self->{DB} };
	 # XXX Can't use while...each --- segfault with 5.8.0
	 for my $k (@keys) {
	     my $v = $self->{DB}{$k};
	     if (!defined $v) {
		 push @undef_values, $k;
	     } elsif (ref $v ne 'ARRAY' || @$v != 4) {
		 push @broken_values, $k;
	     } else {
		 if ($v->[OBJECT]->{Id} ne $k) {
		     push @wrong_ids, $k;
		 }
		 my(@children_ids) = @{$v->[CHILDREN]};
		 my(@parent_ids)   = @{$v->[PARENTS]};
		 my(@version_ids)  = @{$v->[VERSIONS]};
		 for my $def (["c", \@children_ids, \@not_existing_children],
			      ["p", \@parent_ids,   \@not_existing_parents],
			      ["v", \@version_ids,  \@not_existing_versions],
			     ) {
		     my($type, $ids, $res) = @$def;
		     for my $id (@$ids) {
			 if (!exists $self->{DB}{$id}) {
			     push @$res, [$k, $id];
			 } else {
			     if ($type ne "p") {
				 push @{$referenced{$id}}, $k;
			     }
			 }
		     }
		 }
		 for my $id (@children_ids) {
		     if (exists $self->{DB}{$id}) {
			 my $c = $self->{DB}{$id};
		     CHECK_PARENT: {
			     for my $p_id (@{$c->[PARENTS]}) {
				 if ($p_id eq $k) {
				     last CHECK_PARENT;
				 }
			     }
			     push @child_parent_mismatches, [$k, $id];
			 }
		     }
		 }
		 if ($contentdb) {
		     my $o = $v->[WE::DB::Obj::OBJECT];
		     if ($o->is_doc) {
			 my $f = $contentdb->filename($o);
			 if (!-e $f) {
			     push @doc_object_without_content, $o->Id;
			 }
		     }
		 }
	     }
	 }

	 for my $k (@keys) {
	     if (!exists $referenced{$k}) {
		 push @not_referenced, $k;
	     }
	 }
    });

 RETURN:
    @not_existing_children = sort {$a->[0]<=>$b->[0]} @not_existing_children;
    @not_existing_parents  = sort {$a->[0]<=>$b->[0]} @not_existing_parents;
    @not_existing_versions = sort {$a->[0]<=>$b->[0]} @not_existing_versions;
    @not_referenced        = sort {$a<=>$b} @not_referenced;

    bless { "undef_values"               => \@undef_values,
	    "broken_values"              => \@broken_values,
	    "wrong_ids"	                 => \@wrong_ids,
	    "not_existing_children"      => \@not_existing_children,
	    "not_existing_parents"       => \@not_existing_parents,
	    "not_existing_versions"      => \@not_existing_versions,
	    "not_referenced"             => \@not_referenced,
	    "child_parent_mismatches"    => \@child_parent_mismatches,
	    "doc_object_without_content" => \@doc_object_without_content,
	    "root_object_missing"	 => $root_object_missing,
	  }, 'WE::DB::Obj::Fsck';
}

=item repair_database($errors, %args)

Take a C<WE::DB::Obj::Fsck> object with lists of inconsistencies and
tries to repair the C<WE::DB::Obj> database. C<%args> may be:

=over

=item -verbose

Be verbose if set to a true value.

=back

=cut

# errors is the return value of check_integrity() (a WE::DB::Obj::Fsck object)
sub repair_database {
    my($self, $errors, %args) = @_;
    my $v = 1 if $args{-verbose};
    my $root_object_id = $args{-rootobjectid};
    $self->connect_if_necessary(sub {
	if ($errors->{root_object_missing}) {
	    if (!defined $root_object_id) {
		die "rootobjectid not specified";
	    }
	    $self->{DB}{'_root_object'} = $root_object_id;
	}
        foreach my $id (@{ $errors->{"not_referenced"} }) {
	    warn "Remove object $id from database\n" if $v;
	    delete $self->{DB}{$id};
	}
	for my $def ([CHILDREN, "not_existing_children", "child"],
		     [PARENTS,  "not_existing_parents",  "parent"],
		     [VERSIONS, "not_existing_versions", "version"],
		    ) {
	    my($index, $key, $label) = @$def;
	    for my $def2 (@{ $errors->{$key} }) {
		my($id, $refid) = @$def2;
		my $o = $self->{DB}{$id};
		if (!$o) {
		    warn "Object $id does not exist anymore, skipping...\n";
		} else {
		    warn "Remove $label $refid from $id\n" if $v;
		    @{$o->[$index]} = grep { $_ ne $refid } @{$o->[$index]};
		    $self->{DB}{$id} = $o;
		}
	    }
	}
	if ($errors->{doc_object_without_content}) {
	    for my $id (@{ $errors->{doc_object_without_content} }) {
		warn "Remove doc object $id from database (no content file)\n"
		    if $v;
		delete $self->{DB}{$id};
	    }
	}
	warn "Cannot repair undef_values\n" if @{ $errors->{"undef_values"} };
	warn "Cannot repair broken_values\n" if @{ $errors->{"broken_values"} };
    });
}

=back

=cut

package WE::DB::Content;

=head2 METHODS in the WE::DB::Content package

=over

=item check_integrity($objdb)

Return a C<WE::DB::Content::Fsck> object with lists of inconsistencies
in the C<WE::DB::Content> database. The check is done against the
C<WE::DB::Obj> database C<$objdb>.

=cut

sub check_integrity {
    my($self, $objdb) = @_;

    my @extra_files;
    my @unreferenced_files;

    $objdb->connect_if_necessary(sub {
	opendir(D, $self->Directory) or die "Can't open " . $self->Directory . ": $!";
	while(my $f = readdir D) {
	    next if $f =~ /^\.\.?$/;
	    my($id) = $f =~ /^(\d+)\./;
	    if (defined $id) {
		if (!exists $objdb->{DB}{$id}) {
		    push @unreferenced_files, $f;
		}
	    } else {
		if ($f !~ /^(\.svn|CVS|\.cvsignore|\.keep_me|RCS)$/) {
		    push @extra_files, $f;
		}
	    }
	}
	closedir D;
    });

    bless {"unreferenced_files"         => \@unreferenced_files,
	   "extra_files"                => \@extra_files,
	  }, 'WE::DB::Content::Fsck';
}

=item repair_database($errors, %args)

Take a C<WE::DB::Content::Fsck> object with lists of inconsistencies
and tries to repair the C<WE::DB::Content> database. C<%args> may be:

=over

=item -verbose

Be verbose if set to a true value.

=back

=cut

# errors is the return value of check_integrity() (a
# WE::DB::Content::Fsck object)
sub repair_database {
    my($self, $errors, %args) = @_;
    my $v = 1 if $args{-verbose};
    require File::Spec;
    for my $file (@{ $errors->{unreferenced_files} }) {
	my $path = File::Spec->catfile($self->Directory, $file);
	warn "unlink $path\n";
	unlink $path or warn "Can't unlink $path: $!";
    }
    if (@{ $errors->{extra_files} }) {
	warn "Please remove extra files manually, e.g. with
cd @{[ $self->Directory ]} && rm -i @{ $errors->{extra_files} }
";
    }
}


package WE::DB::Fsck;

sub has_errors {
    my $errors = shift;
    foreach (values %$errors) {
	if (ref $_ eq 'ARRAY' && @$_) {
	    return 1;
	}
    }
    if ($errors->has_fatal_errors) {
	return 1;
    }
    0;
}

sub has_fatal_errors {
    my $errors = shift;
    return $errors->{root_object_missing} ? 1 : 0;
}

package WE::DB::Obj::Fsck;
@WE::DB::Obj::Fsck::ISA = 'WE::DB::Fsck';

package WE::DB::Content::Fsck;
@WE::DB::Content::Fsck::ISA = 'WE::DB::Fsck';

1;

__END__

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

