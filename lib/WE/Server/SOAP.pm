# -*- perl -*-

#
# $Id: SOAP.pm,v 1.6 2004/02/15 22:31:20 eserte Exp $
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

package WE::Server::SOAP;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, %args) = @_;
    my $self = {Port => $args{-port}};
    bless $self, $class;
}

sub daemon {
    my($self) = @_;
    #use SOAP::Lite +trace => qw(objects method fault);# XXX only for debugging XXX does not work with 0.55?!
    use SOAP::Transport::HTTP;
    $SIG{PIPE} = 'IGNORE';
    $SIG{INT} = sub { exit(0) };
    my $daemon = SOAP::Transport::HTTP::Daemon
  # if you do not specify LocalAddr then you can access it with 
  # any hostname/IP alias, including localhost or 127.0.0.1. 
  # if do you specify LocalAddr in ->new() then you can only access it 
  # from that interface. -- Michael Percy <mpercy@portera.com>
	-> new (LocalPort => $self->{Port}) 
  # you may also add other options, like 'Reuse' => 1 and/or 'Listen' => 128

  # specify list of objects-by-reference here 
	    -> objects_by_reference(qw(WE_Sample::Root WE::DB WE::DB::Obj WE::DB::User WE::DB::Content))
		->dispatch_to('/home/e/eserte/work/WE_Framework/lib', 'WE_Sample::Root', 'WE::DB::Obj')
		    ->options({compress_threshold => 10000})
			;
    print "Contact to SOAP server at ", $daemon->url, "\n";
    $daemon->handle;
    exit(0);
}

{ package WE::DB::Obj;
  # XXX only for debugging:
  sub get_stored_obj { shift->_get_stored_obj(@_) }
  sub store_stored_obj { shift->_store_stored_obj(@_) }
}

# XXXX so nicht: besser als DB-Pool
#  { package WE_Sample::Root;
#    sub get_db {
#      my($class, $id) = @_;
#      my $obj;
#      if ($id eq 'sample-eserte') {
#  	$obj = WE_Sample::Root->new(-rootdir => "/home/e/eserte/public_html/sample/wwwroot/cgi-bin/we_data",
#  				    -connect => 0,
#  				    -locking => 1);
#      } else {
#  	die "Unhandled id $id";
#      }
#      $obj;
#    }
#  }

return 1 if caller();

package main;

my $ss = WE::Server::SOAP->new(-port => shift||8123);
$ss->daemon;

__END__

=head1 NAME

WE::Server::SOAP - WE_Framework server using the SOAP protocol

=head1 SYNOPSIS

    perl /path/to/WE/Server/SOAP.pm [port]

=head1 DESCRIPTION

Create a server for the WE_Framework using the SOAP protocol. Warning:
there is no access control defined in this module, so use with
caution!

Support for this module is weak.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<SOAP::Lite>.

=cut

