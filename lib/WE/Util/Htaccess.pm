# -*- perl -*-

#
# $Id: Htaccess.pm,v 1.7 2004/04/08 14:26:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002, 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Util::Htaccess;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE::Util::Htaccess - create apache .htaccess files

=head1 SYNOPSIS

    use WE::Util::Htaccess;
    WE::Util::Htaccess::create("/var/www/htdocs/.htaccess", $obj_db
                               -authname => "sample",
                               -authuserfile => "/var/www/.htpasswd",
                               -authgroupfile => "/var/www/.htgroup",
			       -inherit => 1,
			       -add => "ErrorDocument 401 /index.html",
                              );


=head1 DESCRIPTION

This module is used to create Apache C<.htaccess> files from a
C<WE::DB::Obj> database. All objects in the database are traversed (or
restricted by a filter) and if the object contains a C<WWWAuth>
attribute, an entry for the C<.htaccess> file is created.

The C<WWWAuth> attribute should be a string with the following syntax:

    "[user=|group=]id1,[user=|group=]id2..."

If netither "user=" nor "group=" is specified, then a user id is
assumed. Example:

    "bla,group=foo,user=bar"

means: the users C<bla> and C<bar> and the group C<foo>.

The files C<.htpasswd>, C<.htgroup> and C<.htaccess> are always
protected from WWW access, so you can use these names for the
user/group files, if you have to store these files in a WWW readable
directory.

The C<create> function expects the following arguments:

=over 4

=item -authname => $name

The name of the authorization realm. By default it is "WE Authentication".

=item -authtype => $type

The type of user authentication. By default it is "Basic".

=item -authuserfile => $file

The path to the .htpasswd file (see L<WE::Util::Htpasswd>). This is
required unless set by an entry in the global C<httpd.conf>.

=item -authgroupfile => $file

The path to the groups file (see L<WE::Util::Htgroup>). This is
required if there are any group authentifications in the object
database and no entry from the global C<httpd.conf> can be used.

=item -inherit => $bool

If set to true (default) then inherit folder rights to their children
and subfolders.

=item -filter => sub { my($obj) = @_; ... }

A filter callback for restricting an object or sub-tree. The callback
will get the current object as parameter and should return a boolean
value. If the returned value is false, then the object is not
processed; if it is a folder then the descendants of the folder are
not processed either.

=item -add => $string

A C<$string> to be added to the .htaccess file. An example would be to
add an C<ErrorDocument> directive (see
L<http://httpd.apache.org/docs/mod/core.html#errordocument>).

=item -addfile => $file

Like C<-add>, but read the contents from the named file. It is
possible to use C<-add> and C<-addfile> together.

=item -restrict => $restrict

Alternative restriction scheme. If set, then no access to the
C<WE::DB::Obj> database is done. C<-inherit> and C<-filter> are
ignored. The C<$restrict> string should be of the form:

    type1 value1 value2 value3; type2 value4 value5 ...

where I<type> is either C<group> or C<user> and I<value> a group or
user name.

=item -getaliases => sub { my($id) = @_; ... }

This should be a code reference which receives the object id as
parameter and returns a list of alias names for this page (excluding
the supplied id).

=cut

sub create {
    my($dest_file, $obj_db, %args) = @_;

    my $s = _create($obj_db, %args);

    open(D, ">$dest_file") or die "Can't write to $dest_file: $!";
    print D $s;
    close D;
}

sub _create {
    my($obj_db, %args) = @_;

    my $authname = $args{-authname} || "WE Authentication";
    my $authtype = $args{-authtype} || "Basic";
    my $inherit  = defined $args{-inherit} ? $args{-inherit} : 1;
    my $filter   = delete $args{-filter};
    my $restrict = delete $args{-restrict} || "";
    my $get_aliases = delete $args{-getaliases};
    my $add = "";
    if (defined $args{-add}) {
	$add .= "\n" . delete($args{-add}) . "\n";
    }
    if (defined $args{-addfile}) {
	if (!open(ADDFILE, $args{-addfile})) {
	    warn "Can't open file specified in -addfile: $args{-addfile}: $!";
	} else {
	    local $/ = undef;
	    $add .= "\n" . scalar(<ADDFILE>) . "\n";
	    close ADDFILE;
	}
    }

    # get all objects with restrictions
    my %restr_objs;
    if ($restrict eq '') {
	$obj_db->walk_preorder($obj_db->root_object, sub {
            my($id) = @_;
	    my($obj) = $obj_db->get_object($id);

	    return if ($filter && !$filter->($obj));

	    if ($inherit) {
		my(@parent_ids) = $obj_db->parent_ids($id);
		foreach my $p_id (@parent_ids) {
		    if (exists $restr_objs{$p_id}) {
			push @{ $restr_objs{$id} }, @{ $restr_objs{$p_id} };
		    }
		}
	    }

	    if (defined $obj->{WWWAuth} && $obj->{WWWAuth} ne "") {
		my(@auth_token) = split /,/, $obj->{WWWAuth};
		foreach my $auth_token (@auth_token) {
		    if ($auth_token =~ /^([^=]+)=(.*)$/) {
			push @{ $restr_objs{$id} }, [$1, $2];
		    } else {
			push @{ $restr_objs{$id} }, [user => $auth_token];
		    }
		}
	    }
	});
    }

    # norm requirements so it is easier to collect requirements
    my %restr_reqs; # require-string => [objid ...]
    while(my($objid, $reqs) = each %restr_objs) {
	my $require_string = _norm_requirements($objid, $reqs);
	push @{ $restr_reqs{$require_string} }, $objid;
    }

    # create auth/files sections
    my $s = "";
    if ($restrict ne '') {
	$s .= <<EOF;
AuthName "$authname"
AuthType $authtype
EOF
        $s .= "AuthGroupFile $args{-authgroupfile}\n"
	    if $args{-authgroupfile};
	$s .= "AuthUserFile $args{-authuserfile}\n"
	    if $args{-authuserfile};
	my(@token1) = split /\s*;\s*/, $restrict;
	for my $token (@token1) {
	    my($type, @val) = split /\s+/, $token;
	    $s .= "require $type @val\n";
	}
	$s .= "\n";
    } else {
	while(my($restr_reqs, $ids) = each %restr_reqs) {
	    $s .= "<Files ~ \"^(";
	    my @ids = @$ids;
	    my(%aliases, @aliases);
	    if ($get_aliases) {
		for my $id (@ids) {
		    my @new_aliases = $get_aliases->($id);
		    @aliases{@new_aliases} = (1) x @new_aliases;
		}
		@aliases = keys %aliases;
	    }
	    $s .= join("|", map { quotemeta($_) } @ids, @aliases);
	    $s .= ")\\.[^\\.]*\$\">\n";
	    $s .= "AuthName \"$authname\"\n";
	    $s .= "AuthType $authtype\n";
	    $s .= "AuthGroupFile $args{-authgroupfile}\n"
		if $args{-authgroupfile};
	    $s .= "AuthUserFile $args{-authuserfile}\n"
		if $args{-authuserfile};
	    $s .= $restr_reqs;
	    $s .= "</Files>\n\n";
	}
    }

    $s .= _protect_ourselves();

    $s .= $add;

    $s;
}

sub _protect_ourselves {
    <<'EOF'
<Files ~ "^(\.htpasswd|\.htgroup\|.htaccess)">
Order deny,allow
Deny from all
Satisfy All
</Files>

EOF
}

sub _norm_requirements {
    my($objid, $reqs) = @_;
    my %reqs_by_type;
    foreach my $req (@$reqs) {
	my($type, $name) = @$req;
	push @{ $reqs_by_type{$type} }, $name;
    }
    my $require_string = "";
    foreach my $type (sort keys %reqs_by_type) {
	# make unique
	my %values = map {($_=>1)} @{ $reqs_by_type{$type} };
	$require_string .= "require $type " . join(" ", sort keys %values) . "\n";
    }
    $require_string;
}

1;

__END__

=back

=head1 NOTES

Please check the setting of C<AllowOverride> in the global
C<httpd.conf>. This directive should be set to C<All> or at least
C<AuthConfig Limit> for the web.editor-controlled directories. See
also the AllowOverride entry in the Apache documentation:
L<http://httpd.apache.org/docs/mod/core.html#allowoverride>.

For a perl-based httpd.conf use something like:

  $Directory{$document_root}{AllowOverride} = "All";

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Util::Htgroup>, L<WE::Util::Htpasswd>, L<WE::DB::Obj>, L<httpd(8)>.

=cut

