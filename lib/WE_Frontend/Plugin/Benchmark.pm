# -*- perl -*-

#
# $Id: Benchmark.pm,v 1.7 2004/10/27 13:25:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Frontend::Plugin::Benchmark;
use base qw(Template::Plugin);

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use Time::HiRes qw(gettimeofday tv_interval);

sub new {
    my ($class, $context, @params) = @_;
    bless {
	   _CONTEXT => $context,
	   _START => [gettimeofday],
	  }, $class;
}

sub stop {
    my $self = shift;
    my $arg = shift || "";
    $arg .= " " . tv_interval($self->{_START}, [gettimeofday]) . "s";
    warn "$arg\n";
    "";
}

1;

__END__

=head1 NAME

WE_Frontend::Plugin::Benchmark - TT plugin for making benchmarks

=head1 SYNOPSIS

    [% USE b = Benchmark %]
    ...
    [% b.stop(tag) %]

=head1 DESCRIPTION

This plugin may be used to benchmark a code block in a TT template.
The start of the benchmarked block should be marked with:

    [% USE b = Benchmark %]

and the end with

    [% b.stop(tag) %]

The (real, not CPU) run time is written to STDERR. I<tag> is an
arbitrary string which may be used to identify a benchmarked block.

=head1 ALTERNATIVES

On CPAN, the module L<Template::Timer> exists.

This module is based on the following suggestion by Gavin Estey (see the TT
mailing list):

I<You can use a Template::Context subclass to insert timing comments in the
HTML.>

I<Just overried what class is used:>

    $Template::Config::CONTEXT = 'TimingContext';

    package TimingContext;
    use base qw( Template::Context );
    use Time::HiRes qw( gettimeofday tv_interval );
    foreach my $sub (qw( process include )) {
      my $super = __PACKAGE__->can("SUPER::$sub") or die;
      *$sub = sub {
        my $self     = shift;
        my $template = ref $_[0] ? $_[0]->name : $_[0];
        my $start    = [gettimeofday];
        my $data     = $super->($self, @_);
        my $elapsed  = tv_interval($start);
        return "<!-- START: $template -->\n$data\n<!-- END: $template ($elapsed seconds) -->";
      };
    }
    1;

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 2002 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Time::HiRes>.
