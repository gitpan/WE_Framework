# -*- perl -*-

#
# $Id: KeywordIndex.pm,v 1.3 2004/01/28 16:49:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::Plugin::KeywordIndex;
use base qw(Template::Plugin);

use HTML::Entities;

use WE::Util::LangString qw(langstring);
use WE_Frontend::Plugin::WE_Navigation;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

WE_Frontend::Plugin::KeywordIndex - gather site keywords

=head1 SYNOPSIS

    my $t = Template->new({PLUGIN_BASE => "WE_Frontend::Plugin"});

    [% USE KeywordIndex %]
    [% SET keywords = KeywordIndex.array() %]

=head1 DESCRIPTION

Gather keywords and return them to the templating system.

=head2 METHODS

=over

=cut

sub new {
    my($class, $context, $params) = @_;
    my $n = WE_Frontend::Plugin::WE_Navigation->new($context, $params);
    my $self = { WE_Navigation => $n,
		 Context => $context,
	       };
    bless $self, $class;
}

# XXX Possible args:
# * $lang
# * keyword-normalizer as a anonymous subroutine
# * restrictions (use is_released_object or such?)
sub gather_keywords {
    my($self, $rootid, %args) = @_;
    my $wen   = $self->{WE_Navigation};
    my $objdb = $wen->{ObjDB};
    my $lang  = $wen->{Context}->stash->get("lang") || "en";
    $rootid   = $objdb->root_object->Id;
    my %keywords;
    $objdb->walk($rootid,
		 sub {
		     my($id) = @_;
		     my $o = $objdb->get_object($id);
		     my $s = langstring($o->Keywords, $lang);
		     return if !defined $s;
		     my @keywords = split /\s*,\s*/, $s;
		     for my $kw (@keywords) {
			 push @{ $keywords{$kw} },
			     {
			      Id => $id,
			      Title => langstring($o->Title, $lang),
			      Relurl => "$id.html", # XXX do not hardcode extension, use NameDB if possible
			     };
		     }
		 });
    \%keywords;
}

=item array()

Format and output the given text definition.

=cut

# XXX Possible %args:
# * interpolate initials into the result array
# * sort function
sub array {
    my($self) = @_;
    my $keywords = $self->gather_keywords(); # XXX supply objid and %args (from params?)
    my @out;
    for my $kw (sort { uc $a cmp uc $b } keys %$keywords) {
	push @out, {Keyword    => $kw,
		    References => $keywords->{$kw},
		   };
    }
    return \@out;
}

1;

__END__

=back

=head1 EXAMPLES

Here's a complete example for KeywordIndex. This template snippet
creates an alphabetically sorted (case insensitive) list with linked
keywords. If there is more than one reference for one keyword, then
the links are created in the second column, and the links are labelled
with the page titles.

The used classes here are:

=over

=item keywordtable

for the whole table

=item chartitle

for the initial character titles

=item keyword

for the keyword itself

=item reference

for the reference (usually a page title)

=item reflink

for the link part of a keyword or reference

=back

The templating code:

  <noindex><!--htdig_noindex-->
  <table class="keywordtable">
  [% USE KeywordIndex -%]
  [% SET kws = KeywordIndex.array() -%]
  [% SET lastchar = " " -%]
  [% FOR kwdef = kws -%]
   [% SET lastcharmatch = '^(?i:' _ lastchar _ ')' -%]
   [% IF !kwdef.Keyword.match(lastcharmatch) -%]
    [% SET matches = kwdef.Keyword.match('^(.)') -%]
    [% SET lastchar = matches.0 -%]
    <tr><td colspan="2" class="chartitle">[% lastchar | upper %]</td></tr>
   [% END -%]
   <tr>
  [% IF kwdef.References.size == 1 -%]
    <td class="keyword"><a class="reflink" href="[% kwdef.References.0.Relurl | html_entity %]">[% kwdef.Keyword | html_entity %]</a></td>
  [% ELSE -%]
    <td class="keyword">[% kwdef.Keyword | html_entity %]</td>
    <td class="reference">
    [% FOR ref = kwdef.References -%]
     <a class="reflink" href="[% ref.Relurl | html_entity %]">[% ref.Title | html_entity %]</a><br>
    [% END -%]
    </td>
  [% END -%]
   </tr>
  [% END -%]
  </table>
  <!--/htdig_noindex--></noindex>

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<Template::Plugin>.

=cut

