# -*- perl -*-

#
# $Id: Info.pm,v 1.1 2005/01/31 22:29:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE::DB::Info;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(Info File));

use Cwd qw(cwd);
use File::Basename qw(dirname);
use File::Spec;
use YAML ();

sub new {
    my($class, %args) = @_;
    my $self = bless {}, $class;
    if (!exists $args{File}) {
	$args{File} = File::Spec->catfile(cwd, "INFO.yml");
    }
    while(my($k,$v) = each %args) {
	$self->$k($v);
    }
    $self;
}

sub load {
    my $self = shift;
    $self->Info(YAML::LoadFile($self->File));
}

sub getopt {
    my($self, %args) = @_;
    my $info = $self->Info;

    my $make_abs = sub {
	my $f = shift;
	File::Spec->rel2abs($f, dirname($self->File));
    };

    my %opt;
    for my $def ('inc@,abs', 'datadir,abs',
		 qw(rootclass
		    userdbclass userdbclass_file
		    objdbclass objdbclass_file)) {
	my($key, $sigil, $attribs) = $def =~ m{^(.*?)([\@\$\%])?(,.*)?$};
	my %attribs;
	if ($attribs) {
	    %attribs = map {($_,1)} split /,/, substr($attribs, 1);
	}
	if (exists $info->{$key}) {
	    if ($sigil && $sigil eq '@') {
		if (UNIVERSAL::isa($info->{$key}, "ARRAY")) {
		    $opt{$key} = $info->{$key};
		} else {
		    $opt{$key} = [ $info->{$key} ];
		}
		if ($attribs{'abs'}) {
		    for (@{$opt{$key}}) {
			$_ = $make_abs->($_);
		    }
		}
	    } else {
		$opt{$key} = $info->{$key};
		if ($attribs{'abs'}) {
		    $opt{$key} = $make_abs->($opt{$key});
		}
	    }
	}
    }
    %opt;
}

1;

__END__

=head1 NAME

WE::DB::Info - handle INFO.yml files in the we data directory

=head1 EXAMPLE

An example INFO.yml file could look like this:

    inc:                    "../lib"
    datadir:                "."
    rootclass:              Routopedia::DB
    userdbclass:            Routopedia::UserDB
    userdbclass_file:       Routopedia::DB

=cut
