# -*- perl -*-

#
# $Id: HWObj.pm,v 1.3 2003/01/16 14:29:10 eserte Exp $
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

package WE::DB::HWObj;

use base qw/WE::DB::Obj/;
use WE::Util::LangString;

__PACKAGE__->mk_accessors(qw/HWHost HWPort HWRoot HW/);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use HyperWave::CSP;

{package HyperWave::CSP;
 use vars qw($DEBUG); $DEBUG=0;

#
# Reads up to the number of bytes from the socket
# returns 0 on failure, otherwise the buffer read
#
sub _hw_read {
   my $socket = shift;
   my $length_to_read = shift;

   warn "_hw_read\n" if $DEBUG > 2;

   my $buff1 = "0.02";
   my $tries_remaining = 20;

   # loop until it's all read, or we timeout
   if (!defined(sysread($socket, $buff1, $length_to_read))) {
      warn "_hw_read: sysread: $!";
   }
   $length_to_read -= length($buff1);
   my $buffer = $buff1;
   while ($length_to_read && $tries_remaining) {
      select(undef,undef,undef,0.01);
      #sleep(5);
      $tries_remaining--;
      $buff1 = "0.02";
      if (!defined(sysread($socket, $buff1, $length_to_read))) { 
         warn "_hw_read: sysread: $!";
      }
      $length_to_read -= length($buff1);
      $buffer .= $buff1;
      warn "_hw_read: read = \"0.02\" of " . 
         $length_to_read . "\n" if $DEBUG > 2;
   }

   if (!$tries_remaining) {
      warn "_hw_read: ran out of tries!\n";
      return 0;
   }

   warn "_hw_read: returning = '$buffer'\n" if $DEBUG > 2;
   return $buffer;

}
}

sub new {
    my($class, $root, %hwargs) = @_;
    my $self = {};
    bless $self, $class;
    $self->Root($root);
    $self->HWHost($hwargs{-host});
    $self->HWPort($hwargs{-port});
    $hwargs{-rootcollection} = "rootcollection"
	if (!defined $hwargs{-rootcollection});
    $self->HWRoot($hwargs{-rootcollection});
    $self;
}

sub root_object {
    my $self = shift;
    my $rootid = $self->HW->get_objnum_by_name($self->HWRoot);
    if (defined $rootid) {
	my(%a) = $self->HW->get_attributes_hash($rootid);
	$self->_change_attributes(\%a);
	return WE::Obj::Site->new(%a);
    } else {
	undef;
    }
}

sub get_object {
    my($self, $obj_id) = @_;
    my(%a) = $self->HW->get_attributes_hash($obj_id);
    $self->_change_attributes(\%a);

    if ($a{'DocumentType'} eq 'collection') {
	WE::Obj::FolderObj->new(%a);
    } elsif (scalar keys %a) {
	WE::Obj::DocObj->new(%a);
    } else {
	undef;
    }
}

sub exists {
    my($self, $obj_id) = @_;
    defined $self->HW->get_attributes($obj_id);
}

sub children_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->HW->get_children($obj_id);
    $o ? split /\s+/, $o : ();
}

sub parent_ids {
    my($self, $obj_id) = @_;
    $self->idify_params($obj_id);
    my $o = $self->HW->get_parents($obj_id);
    $o ? split /\s+/, $o : ();
}

sub version_ids { die "NYI" }

sub idify_params {
    my $self = shift;
    foreach (@_) {
	if (UNIVERSAL::isa($_, "WE::Obj")) {
	    $_ = hex $_->{ObjectID};
	}
    }
}

sub _change_attributes {
    my($self, $aref) = @_;
    my @titles;
    while(my($name, $value) = each %$aref) {
	if ($name eq 'Author') { $name = 'Owner' }
	elsif ($name =~ /^Time(Created|Modified)$/) { $value = hwdate2isodate($value) }
	elsif ($name eq 'MimeType') { $name = 'ContentType' }
	elsif ($name eq 'Title') { push @titles, $value; next }
	elsif ($name eq 'ObjectID') { $aref->{Id} = hex $value }
	$aref->{$name} = $value;
    }
    if (@titles) {
	$aref->{Title} = hwtitle2langstr(@titles);
    }
    $aref;
}

sub hwdate2isodate {
    my $hwdate = shift;
    $hwdate =~ s/^(\d+)\/(\d+)\/(\d+)/$1-$2-$3/;
    $hwdate;
}

sub hwtitle2langstr {
    my(@titles) = @_;
    my %t;
    foreach (@titles) {
	if (/^([^:]+):(.*)$/) {
	    $t{$1 eq 'ge' ? 'de' : $1} = $2;
	} else {
	    warn "Can't parse title $_";
	}
    }
    new WE::Util::LangString %t;
}

1;

__END__

=head1 NAME

WE::DB::HWObj - interface to hyperwave objects

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

=cut

