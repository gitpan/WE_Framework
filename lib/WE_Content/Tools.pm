# -*- perl -*-

#
# $Id: Tools.pm,v 1.7 2004/04/13 21:48:50 eserte Exp $
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

package WE_Content::Tools;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

package WE_Content::Base;

=head1 NAME

WE_Content::Tools - tools for content objects

=head1 SYNOPSIS

    use WE_Content::Tools;
    $content_object->find(sub { ... });

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item get_structure_diffs($template)

Return a list of differences against a template object. Only language
data is compared. See L<Algorithm::Diff> for the output format.

=cut

sub get_structure_diffs {
    my($self, $template) = @_;
    die "Template should be a template" if !$template->{Type} eq 'template';
    require Algorithm::Diff;
    require Data::Dumper;

    my %ret;

    while(my($lang, $langval) = each %{ $self->{Object}->{'data'} }) {
	next unless (UNIVERSAL::isa($langval, 'HASH') &&
		     exists $langval->{'ct'});
	my $ct = $langval->{'ct'};
	my $template_ct = $template->{Object}{'ct'};
	my(@diffs) = Algorithm::Diff::diff
	    ($template_ct, $ct,
	     sub { Data::Dumper->new([shift],['n'])->Sortkeys(1)->Dump }
	    );

	$ret{$lang} = \@diffs;
    }

    %ret;
}

=item upgrade($template)

Upgrade the content file to the current $template.

=cut

sub upgrade {
    my($self, $template) = @_;
    die "Template should be a template" if !$template->{Type} eq 'template';

    require Storable;

    my $_upgrade = sub {
	my($ct, $template_ct) = @_;
	for my $i (0 .. $#$ct) {
	    my $ct_node  = $ct->[$i];
	    my $tct_node = $template_ct->[$i];
	    if ($ct_node->{type} eq $tct_node->{type} &&
		$ct_node->{name} eq $tct_node->{name}
	       ) {
		my $ct_cancontain  = join("|", $ct_node->{cancontain});
		my $tct_cancontain = join("|", $tct_node->{cancontain});
		if ($ct_cancontain ne $tct_cancontain) {
		    $ct_node->{cancontain} = Storable::dclone($tct_node->{cancontain});
		}
	    }
	}
    };

    while(my($lang, $langval) = each %{ $self->{Object}->{'data'} }) {
	next unless (UNIVERSAL::isa($langval, 'HASH') &&
		     exists $langval->{'ct'});
	my $ct = $langval->{'ct'};
	my $template_ct = $template->{Object}{'ct'};
	$_upgrade->($ct, $template_ct);
    }
}

sub simple_diff {
    my($self, $self2) = @_;
    require Algorithm::Diff;
    my(@ret) = Algorithm::Diff::diff([$self->{Object}], [$self2->{Object}], \&_diff_key);
    @ret;
}

sub _diff_key {
    my($o) = @_;
    if (ref $o eq 'HASH') {
	my @s;
	foreach my $key (sort keys %$o) {
	    push @s, $key, _diff_key($o->{$key});
	}
	"{".join("|", @s)."}"; # XXX may fail if there are "|" in the keys
    } elsif (ref $o eq 'ARRAY') {
	"[".join("|", map { _diff_key($_) } @$o)."]";
    } else {
	$o;
    }
}

=item find($callback)

Traverses the content object and calls C<$callback> for each node in
the content tree. The following arguments will be supplied to the
callback:

=over

=item $object

C<$object> is aa reference to the current object. A change to this
reference will also manipulate the original object.

=item -parents => [$parent1, $parent2, ...]

A list of parent objects. The root object is not in the list.
Descendants are appended to the right, that is, too find the parent
use C<[-1]> as index, the grandfather is C<[-2]> and Adam is C<[0]>.

=item -path => $pathstring

The C<$pathstring> can be evaluated to access the node. Example:

   ->{'data'}->[0]->{'type'}

=item -dotted => $dotstring

Same as C<-path>, but use a dot notation. Example:

   data.0.type

=item -key => $key

Only for hash items: C<$keys> is the current key. The value is in
C<$object>.

=back

TODO:

  implement prune
  suggest to add something similar to Data::Walker

=cut

sub find {
    my($self, $wanted) = @_;
    $self->_find($self->{Object}, $wanted,
		 -parents => [], -path => "", -dotted => "");
}

sub _find {
    my($self, $o, $wanted, %args) = @_;
    $wanted->($o, %args);

    my %extra_args;
    $extra_args{-parents} = [@{ $args{-parents} }, $o];
    if (ref $o eq 'ARRAY') {
	my $ii = 0;
	my $parent_dotted = $args{-dotted} ne "" ? "$args{-dotted}." : "";
	foreach my $i (@$o) {
	    $self->_find($i, $wanted,
			 -path => $args{-path}."->[$ii]",
			 -dotted => $parent_dotted.$ii,
			 %extra_args);
	    $ii++;
	}
    } elsif (ref $o eq 'HASH') {
	my @keys = keys %$o;
	my $parent_dotted = $args{-dotted} ne "" ? "$args{-dotted}." : "";
	foreach my $k (@keys) {
	    my $v = $o->{$k};
	    $self->_find($v, $wanted,
			 -key => $k,
			 -path => $args{-path}."->{'$k'}", # XXX quote?
			 -dotted => $parent_dotted.$k,
			 %extra_args);
	}
    }
}

1;

__END__

=back

=head1 EXAMPLES

This example script will set the title element of the "en" language
tree to the first text (usually the headline):

    use WE_Content::Base;
    use WE_Content::Tools;
    use strict;
    use File::Basename;
    
    my $indir = shift or die;
    my $outdir = "/tmp/we_data_converted";
    mkdir $outdir;
    
    for my $f (glob("$indir/content/*.bin")) {
        warn "$f...\n";
        my $content_object = WE_Content::Base->new(-file => $f) or die;
        my $first_text;
        my $title;
        $content_object->find(sub {
            my($o, %args) = @_;
    	    #if ($args{-dotted} eq "data.en.ct.0.text") {
    	    if ($args{-path} eq "->{'data'}->{'en'}->{'ct'}->[0]->{'text'}") {
    	        $first_text = $o;
    	    } elsif ($args{-path} eq "->{'data'}->{'en'}->{'title'}") {
                $title = $o;
            }
    	});
        #if (defined $title) {
        #    warn "Skipping, title is already set to $title.\n";
        #} els
        if (defined $first_text) {
    	    #$content_object->set_by_dotted('data.en.title', $first_text);
    	    $content_object->{Object}{'data'}->{'en'}->{'title'} = $first_text;
        } else {
            warn "No first text found...\n";
        }
        open(OUT, ">$outdir/" . basename($f)) or die $!;
        print OUT $content_object->serialize;
        close OUT;
    }

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<WE_Content::Base>.

=cut

