# -*- perl -*-

#
# $Id: TBPJobManager.pm,v 1.3 2005/03/22 09:59:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WebEditor::OldController::TBPJobManager;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(AJM Controller DBFile DB));

use MLDBM;
use Data::Dumper;
use DB_File::Lock;

use WE::Util::AtJobManager;

=head1 NAME

WebEditor::OldController::TBPJobManager - manager for time based publishing jobs

=cut

sub new {
    my($class, $ctrl) = @_;
    my $self = bless {}, $class;
    $self->AJM       (WE::Util::AtJobManager->new(queue => "w"));
    $self->Controller($ctrl);
    $self->DBFile    ($ctrl->Root->RootDir . "/tbp.db");
    $self->open_db;
    $self;
}

sub open_db {
    my $self = shift;
    local $MLDBM::Serializer = "Data::Dumper";
    local $MLDBM::UseDB      = "DB_File::Lock";
    tie my %db, "MLDBM", $self->DBFile, O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH, "write"
	or die "Can't tie to " . $self->DBFile . ": $!";
    $self->DB(\%db);
}

sub synchronize_at_jobs {
    my $self = shift;

    my $ctrl = $self->Controller;
    my $objdb = $ctrl->Root->ObjDB;
    my(%to_events, %te_events);
    $objdb->walk($objdb->root_object->Id, sub {
        my $id = shift;
	my $obj = $objdb->get_object($id);
	if ($obj->TimeOpen) {
	    push @{ $to_events{$obj->TimeOpen} }, [$id, $obj->Title];
	}
	if ($obj->TimeExpire) {
	    push @{ $to_events{$obj->TimeExpire} }, [$id, $obj->Title];
	}
    });

    my %done_events;    # Events done since the last visit. Will be deleted after presenting them.
    my %new_events;     # New events to be inserted in the queue
    my %expired_events; # Events which are expired , %new_events,
#       %pend
}

1;

__END__
