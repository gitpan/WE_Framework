# -*- perl -*-

#
# $Id: Glossary.pm,v 1.5 2004/02/23 07:27:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://rezic.de/eserte
#

package WE::DB::Glossary;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(DB Root));

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use MLDBM;
use Fcntl;

{
    package WE::GlossaryObj;
    use base qw(Class::Accessor);
    __PACKAGE__->mk_accessors
	(qw(Keyword Description));
    sub new { bless {}, $_[0] }
}

{
    # this will be written to the database and should not be used otherwise
    package WE::DB::Glossary::DBInfo;
    use base qw(Class::Accessor);
    __PACKAGE__->mk_accessors(qw());
    sub new { bless {}, $_[0] }
}

sub new {
    my($class, $root, $file, %args) = @_;
    my $self = {};

    $args{-db}         = "DB_File" unless defined $args{-db};
    $args{-serializer} = "Data::Dumper" unless defined $args{-serializer};
    $args{-locking}    = 0 unless defined $args{-locking};
    $args{-readonly}   = 0 unless defined $args{-readonly};
    $args{-writeonly}  = 0 unless defined $args{-writeonly};

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
	push @tie_args, $DB_File::DB_BTREE;
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

    tie %{ $self->{DB} }, 'MLDBM', $file, @tie_args
	or require Carp, Carp::confess("Can't tie MLDBM database $file with args <@tie_args>, db <$MLDBM::UseDB> and serializer <$MLDBM::Serializer>: $!");

    bless $self, $class;
    $self->Root($root);

    # read database information
    my $db_info = $self->DB->{__DBINFO__};
    if (!defined $db_info) {
	$db_info = $self->DB->{__DBINFO__} = new WE::DB::Glossary::DBInfo;
    }
    # sync members with DBINFO
    if ($db_info) {
      # none yet
    }
    # set %args
    # none yet
    # write back database information
    if (!$args{-readonly}) {
	$self->DB->{__DBINFO__} = $db_info;
    }

    $self;
}

sub add_entry {
    my($self, @args) = @_;
    my %args;
    for(my $i=0; $i<=$#args; $i++) {
	if ($args[$i] =~ /^-/) {
	    $args{$args[$i]} = $args[$i+1];
	    splice @args, $i, 2;
	    $i--;
	}
    }

    my $obj;
    if (UNIVERSAL::isa($args[0], "WE::GlossaryObj")) {
	$obj = $args[0];
    } else {
	my %obj_args = @args;
	$obj = WE::GlossaryObj->new;
	$obj->$_($obj_args{$_}) for (qw(Keyword Description));
    }

    if (exists $self->{DB}->{$obj->Keyword}) {
	if (!$args{-force}) {
	    require Carp, Carp::confess("There is already a glossary entry for keyword " . $obj->Keyword);
	}
    }

    $self->{DB}->{$obj->Keyword} = $obj;
    $obj;
}

sub delete_entry {
    my($self, $keyword) = @_;
    delete $self->{DB}->{$keyword};
}

sub get_entry {
    my($self, $keyword) = @_;
    $self->{DB}->{$keyword};
}

sub get_descr {
    my($self, $keyword) = @_;
    my $obj = $self->get_entry($keyword);
    return undef if !$obj;
    $obj->Description;
}

sub all_keywords_regex {
    my($self, $filter) = @_;
    my @keywords;
    while(my($k,$v) = each %{ $self->{DB} }) {
	next if $k =~ /^__/; # skip special keys
	next if ($filter && !$filter->($k));
	push @keywords, $k;
    }
    "(" . join("|", map { "\\b" . quotemeta($_) . "\\b" } @keywords) . ")";
}

1;

__END__

=head1 NAME

WE::DB::Glossary - glossary data database.

=head1 SYNOPSIS

    my $u = WE::DB::Glossary->new(undef, $glossary_db_file, %args);

    $u->add_entry(Keyword => ..., Description => ...);
    $glossary_obj = $u->get_entry($keyword);


=head1 DESCRIPTION

Database for administration of glossary entries. You can add, delete,
modify and retrieve glossary entries.

=head2 WE::GlossaryObj

The glossary entries are C<WE::GlossaryObj> objects with the following
members:

=over 4

=item Keyword

The keyword for this entry. The keyword is also used as the key in the
database hash.

=item Description

The descriptive text for this keyword. The value is opaque and may be
language-dependent (e.g. by using WE::Util::LangString), HTML or plain
text or whatever.

=back

=head2 METHODS

The following methods are defined for C<WE::DB::Glossary>:

=over 4

=item add_entry(Keyword => ..., Description => ..., -force => 1)

Add a glossary object with Keyword and Description. If C<-force> is
set to true, then existing entries will get overwritten, otherwise an
exception will be raised.

=item add_entry($glossaryobj, -force => 1)

Like the other add_entry() method, but use a pre-build
C<WE::GlossaryObj> object instead.

=item delete_entry($keyword)

Delete the named entry.

=item get_entry($keyword)

Get a C<WE::GlossaryObj> object for the specified $keyword or undef.

=item get_descr($keyword)

Retrieve the description element for the specified $keyword or undef.

=item search($regex)

Return a list of C<WE::GlossaryObj>s which keywords match the given
regular expression. NYI.

=item all_keywords_regex([$filter])

Create a regular expression with all keywords used in the
database. The $filter is optional and should be a code reference
accepting the keyword as first parameter and return a boolean value
for acceptance.

=back

=head1 AUTHORS

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE::DB>, L<MLDBM>

=cut

