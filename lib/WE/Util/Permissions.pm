# -*- perl -*-

#
# $Id: Permissions.pm,v 1.10 2004/10/11 22:08:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2004 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE::Util::Permissions;
use WE::Util::GenericTree::FromString;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0; # possible values 0 .. 2

=head1 NAME

WE::Util::Permissions - rule-based permission model

=head1 SYNOPSIS

    use WE::Util::Permissions;
    $p = WE::Util::Permissions->new(-file => $permissionsfile);
    $p->is_allowed(-user => "user", -group => \@groups, -process => "delete");

=head1 DESCRIPTION

This is a rule-based permission system. All permissions are stored in
a single file, so it is easy to see all the permissions on one look.

See L</PERMISSION FILE SYNTAX> for a description of this file's
syntax.

=head2 METHODS

=over

=item new($class, %args)

Create a C<WE::Util::Permissions> object. At least one of the following named parameters should be given:

=over

=item -string => $string

A string with the permission data.

=item -file => $file

A file with the permission data.

=item -objectfromfile => $file

A file containg a dump of a Permission object.

=back

=cut

sub new {
    my($class, %args) = @_;
    my $self = {};
    $self->{Directives} = {};
    bless $self, $class;
    if ($args{'-string'}) {
	$self->parse($args{'-string'});
    } elsif ($args{'-file'}) {
	local $/ = undef;
	open(F, $args{'-file'}) or die "Can't open $args{'-file'}: $!";
	my($s) = <F>;
	close F;
	$self->parse($s);
    } elsif ($args{'-objectfromfile'}) {
	local $/ = undef;
	open(F, $args{'-objectfromfile'}) or die "Can't open $args{'-objectfromfile'}: $!";
	my($s) = <F>;
	close F;
	$self->_eval_obj($s);
    } else {
	die "Either -string or -file should be given as argument!";
    }
    $self;
}

=item parse($string)

Internal function. Parse the C<$string> into the internal
representation. Normally, this is called automatically on construction
time.

=cut

sub parse {
    my($self, $string) = @_;
    my $new_s = "";
    my $directives = {};
    foreach my $line (split/\n/, $string) {
	$line =~ s/\#.*$//; # delete comments
	$line =~ s/\s+$//; # delete whitespace on end
	next if $line eq ''; # ignore empty lines
	if (my($key,$val) = $line =~ /^!\s*(\S+)\s*:\s*(.+)$/) { # directive
	    if (exists $directives->{$key}) {
		die "Can't set multiple $key directives in permissions file";
	    }
	    $directives->{$key} = $val;
	}
	$new_s .= $line . "\n";
    }
    my $tree = WE::Util::GenericTree::FromString->new($new_s);
    $self->{Def} = $tree;
    $self->{Directives} = $directives;
}

sub _eval_obj {
    my($self, $s) = @_;
    eval 'package Permissions::_eval_; ' . $s;
    die "Can't eval $s: $@" if $@;
    die "No Def object in file" unless defined $Permissions::_eval_::Def;
    $self->{Def} = $Permissions::_eval_::Def;
    undef $Permissions::_eval_::Def;
}

=item save($file)

Save the Permission object to file C<$file>. The file may be reread
using the C<-objectfromfile> argument in C<new>.

=cut

sub save {
    my($self, $file) = @_;
    open(F, ">$file") or die "Can't write to $file: $!";
    require Data::Dumper;
    print F Data::Dumper->Dump([$self->{Def}], ['Def']);
    close F;
}

=item is_allowed(%args)

Return true, if the process for the specified user/group and specified
page is allowed. The keys of C<%args> may be: C<-user>, C<-group> (an
array reference to a group list), C<-process>, and C<-page>.

=cut

sub is_allowed {
    my($self, %args) = @_;
    my %new_args;
    while(my($k,$v) = each %args) {
	$new_args{substr($k,1)} = $v; # strip dash
    }
    $self->_is_allowed($self->{Def}, \%new_args);
}

=item get_all_users($usersref, $process, $page)

Return a list of all users which are allowed to do C<$process> in
C<$page>. The C<$usersref> should contain all users in the system and
may be a reference to an array or a reference to an hash. In the
latter case, the keys are the user names and the values an array
reference to the groups of the user. For example:

    $p->get_all_users([qw(eserte ole veit)], "publish", "home");

    $p->get_all_users({eserte => ['admin','editor'],
                       ole    => ['admin'],
                       veit   => ['editor']}, "publish", "home");

=cut

sub get_all_users {
    my($self, $usersref, $process, $page) = @_;

    my @res;
    my @all_users;
    my %groups;
    if (ref $usersref eq 'HASH') {
	@all_users = keys %$usersref;
	%groups = %$usersref;
    } else {
	@all_users = @$usersref;
    }

    my @args;
    if (defined $process) { push @args, -process => $process }
    if (defined $page)    { push @args, -page    => $page }
    foreach my $user (@all_users) {
	my @group_arg = (exists $groups{$user}
			 ? (-group => $groups{$user})
			 : ()
			);
	push @res, $user if $self->is_allowed(-user => $user,
					      @group_arg,
					      @args);
    }
    @res;
}

=item get_all_page_permissions($usersref, $processref, $page)

Return permissions for all users for the specified C<$page>. Arguments
are similar to that of C<get_all_users>, except that C<$processref>
takes an array reference with all allowed processes. The returned
object is a hash reference with the following format:

    { process1 => [user1, user2, ...],
      process2 => [user3, user4, ...],
      ...
    }

=cut

sub get_all_page_permissions {
    my($self, $usersref, $processref, $page, %args) = @_;
    my $info = {};
    foreach my $process (@$processref) {
	$info->{$process} = [$self->get_all_users($usersref, $process, $page)];
    }
    $info;
}

sub _is_allowed {
    my($self, $tree, $args_ref) = @_;
    foreach my $subtree ($tree->subtree) {
	if ($self->_match($subtree->data, $args_ref)) {
	    if (@{$subtree->subtree}) {
		my $r = $self->_is_allowed($subtree, $args_ref);
		return 1 if $r;
	    } else {
		return 1;
	    }
	}
    }
    0;
}

sub _match {
    my($self, $perm, $args_ref) = @_;
    my $matchtype = ($self->{Directives} && $self->{Directives}{match}
		     ? $self->{Directives}{match} : 'glob');
    my(@big_or) = split /\s*;\s*/, $perm;
    foreach my $term (@big_or) {
	my(@args) = split /[\s,]+/, $term;
	my $permtype = shift @args;
	my $args_permtype = $args_ref->{$permtype};
	warn "term @args against " .
	    (defined $args_permtype
	     ? (ref $args_permtype eq 'ARRAY'
		? "@$args_permtype"
		: $args_permtype
	       )
	     : "<undef>"
	    ) . " ...\n" if DEBUG;
	if ($args_permtype) {
	    my @terms = (ref $args_permtype eq 'ARRAY'
			 ? @{ $args_permtype }
			 :    $args_permtype
			);
	    foreach my $arg_ (@args) {
		my $arg = $arg_;
		my $no  = 0;
		if ($arg =~ /^!(.*)/) {
		    $arg = $1;
		    $no = 1;
		}
		my $check_sub;
		if ($matchtype eq 'glob') {
		    my $repl = { '*' => '.*',
				 '?' => '.',
			       };
		    if ($arg =~ /[\*\?]/) {
			$arg =~ s/(.*?)([\*\?])([^\*\?]*)/"\Q$1\E" . $repl->{$2} . "\Q$3\E"/ge;
			$arg = qr/^$arg$/;
			warn "Glob -> regexp: $arg\n" if DEBUG >= 2;
			$check_sub = sub { /$arg/ };
		    } else {
			$check_sub = sub { $_ eq $arg };
		    }
		} elsif ($matchtype =~ /^(rx|regexp?)$/) {
		    $check_sub = sub { /^$arg$/ };
		} else {
		    die "Invalid match type: $matchtype";
		}

		if ($no) {
		    return 0 if grep { $check_sub->() } @terms;
		} else {
		    return 1 if grep { $check_sub->() } @terms;
		}
	    }
	}
    }
    0;
}

=item get_directive($directive)

Return the value of the global directive C<$directive>, or undef.

=cut

sub get_directive {
    my($self, $directive) = @_;
    if (exists $self->{Directives}{$directive}) {
	$self->{Directives}{$directive};
    } else {
	undef;
    }
}

1;

__END__

=back

=head2 PERMISSION FILE SYNTAX

The permission file consists of a set of rules, each rule in one line.
Rules with indentation are attached to the previous rule (the rule
with one space less as the current rule). Such a rule chain may be
read from top to bottom, if all rules in a rule chain apply, then the
query is successful.

Rules consists of tokens followed by a space or comma separated list
of arguments. The following tokens may be used: C<user>, C<group>,
C<process>, and C<page>.

The semantics of users, groups, processes and pages are usually
defined in another layer.

=over

=item user

A list of users.

=item group

A list of groups. Groups and users may be specified in the same line;
in this case they should be separated by a semicolon.

If you want a section-role based group model, then it is recommended
to use a separator (e.g. "/") to separate section and role. For
example, a "chiefeditor" for the section "relations" should be
specified as "relations/chiefeditor". If the current rule applies for
all members of the "relations" section, then it could easily be
written as "relations/*". On the other hand, if the rule applies to
all chief editors, then it could be written as "*/chiefeditor".

=item process

A process is an operation like "publish", "edit", or "delete".

=item page

This can be a path, for example like a common Unix path separated by
"/". See L<WE::DB::Obj/pathname|the pathname method in the WE::DB:Obj
documentation> for more information about the pathname syntax. By
default, the pathnames are composed by the english titles, but this
can be changed by setting the directive C<primarylang>:

    ! primarylang: de

=back

If multiple arguments are put in a rule, then at least one of the
arguments have to match. If an argument is preceded by "!", then the
rule will not match for this argument. For example if you want to deny
"admin" rights, but grant all other rights, then you can write

    process !admin *

By default, simple "glob" matching is used: the "*" character is
recognized as a joker (matches zero to many characters) and the "?"
character matches exactly one character. See </BUGS> for using spaces
in tokens.

By specifying the directive

    ! match: regexp

on top of the permission file, regular expression matching is turned
on. It is not possible to specify multiple match directives.

=head1 EXAMPLES

Here are some rule chain examples for permission files:

    ! match: glob
    group admin
     process *

Use globbing instead of regular expressions for matching and allow the
"admin" group to have rights for all processes. There is no page
restriction, so the rights are valid for all objects.

    group chiefeditor
     process release publish edit

The chiefeditors have rights for the processes "release", "publish"
and "edit". Here too, there are no page restrictions.

    ! match: regexp
    group news
     page /News/.*
      process edit change-folder new-doc rm-doc release publish

The members of the group "news" are allowed to do the following
operations in all objects below "/News/": "edit", "change-folder",
"new-doc", "rm-doc", "release" and "publish". Note that a regular
expression match is used here (there is no "! match" directive).

    ! match: glob
    group *
     process !*

This rule chain should be the last one in every permissions file. It
forbids all operations for all groups and is only fired, if no other
rule chain is successful.

=head1 BUGS

There is currently no way to specify a token with spaces or slashes.
To workaround this, use glob matches and the "?" meta character to
match a space. For example, to match everything under "/Handset
Matrix/", use this rule:

 page /Handset?Matrix/*

This may change by introducing quotes and escape characters à la unix
shells, so do not use single or double quotes or backslashes in path
specifications.

Diagnostics is poor. Unrecognized tokens won't cause errors or
warnings. For some debugging aid, set the DEBUG constant in this
module to a true value.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::Util::GenericTree>.

=cut

