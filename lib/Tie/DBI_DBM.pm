# -*- perl -*-

#
# $Id: DBI_DBM.pm,v 1.4 2003/12/16 15:21:23 eserte Exp $
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

package Tie::DBI_DBM;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use DBI;
use Carp;

sub TIEHASH {
    my $class = shift;
    my $dsn = shift;
    $dsn = "dbi:$dsn" unless $dsn=~ /^dbi/;
    my %opt;
    if (ref $_[0] eq 'HASH') {
	%opt = %{$_[0]};
    } else {
	%opt = @_;
    }

    my $self = {};
    my(@t) = split /\;/, $dsn;
    my $table = delete $opt{'table'} || 'pdata';
    my $key   = delete $opt{'key'}   || 'pkey';
    my $val   = delete $opt{'val'}   || 'pval';

    my $dbh = DBI->connect($dsn, $opt{user}, $opt{password}, \%opt);
    croak "TIEHASH: Can't open $dsn, $DBI::errstr" unless $dbh;

    $self->{DBH} = $dbh;
    $self->{ALL} = $dbh->prepare("SELECT $key FROM $table");
    $self->{FETCH} = $dbh->prepare("SELECT $val FROM $table WHERE $key = ?");
    $self->{UPDATE} = $dbh->prepare("UPDATE $table SET $val = ? WHERE $key = ?");
    $self->{INSERT} = $dbh->prepare("INSERT INTO $table ($key, $val) VALUES (?, ?)");
    $self->{DELETE} = $dbh->prepare("DELETE FROM $table WHERE $key = ?");
    bless $self, $class;
}

sub FETCH {
    my($self, $key) = @_;
    $self->{FETCH}->execute($key);
    my $val = $self->{FETCH}->fetch->[0];
    $self->{FETCH}->finish;
    $val;
}

sub STORE {
    my($self, $key, $val) = @_;
    $self->{FETCH}->execute($key);
    if (!$self->{FETCH}->rows) {
	$self->{INSERT}->execute($key, $val);
    } else {
	$self->{UPDATE}->execute($val, $key);
    }
    $self->{FETCH}->finish;
}

sub DELETE {
    my($self, $key) = @_;
    $self->{DELETE}->execute($key);
}

sub FIRSTKEY {
    my($self) = @_;
    $self->{ALL}->execute();
    $self->NEXTKEY;
}

sub NEXTKEY {
    my($self) = @_;
    my $ref = $self->{ALL}->fetch;
    $ref ? $ref->[0] : undef;
}

sub DESTROY {
    my $self = shift;
    $self->{DBH}->disconnect;
}

1;

__END__

=head1 NAME

Tie::DBI_DBM - a tie interface to DBI databases

=head1 SYNOPSIS

    tie %db, 'Tie::DBI_DBM', "dbi:mysql:test",
                              table=>"dbm",key=>"pkey",val=>"pval",
                              user=>"user",password=>"password"
        or die $!;
    $db{12345} = "val for 12345";
    print $db{12345}; # yields: val for 12345

=head1 DESCRIPTION

The interface is as far as possible compatible with that of
L<Tie::RDBM|Tie::RDBM>.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<DBI>, L<Tie::RDBM>, L<AnyDBM_File>.

=cut

