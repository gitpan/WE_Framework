# -*- perl -*-

#
# $Id: MIME.pm,v 1.3 2003/01/19 14:31:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE::Util::MIME;
use base qw(Exporter);

use strict;
use vars qw($VERSION %mime_types @EXPORT @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);
@EXPORT = qw(get_mime_type_by_filename);
@EXPORT_OK = qw(%mime_types);

# just a fallback...
%mime_types = ("text/html"  => [qw/html htm/],
	       "text/plain" => [qw/txt text/],
	       "image/gif"  => [qw/gif/],
	       "image/jpeg" => [qw/jpg jpeg/],
	       "image/png"  => [qw/png/],
	       "image/x-xpixmap" => [qw/xpm/],
	      );

sub get_mime_type_by_filename {
    my $filename = shift;
    (my $ext = $filename) =~ s/^(.+)\.([^.]+)$/$2/;
    if (eval 'require MIME::Types; 1') {
	my($mime_type) = MIME::Types::by_suffix($ext);
	return $mime_type if defined $mime_type;
    }
    # fallback...
    scalar keys %mime_types; # reset iterator
    while(my($mimetype,$exts) = each %mime_types) {
	foreach my $search_ext (@$exts) {
	    if ($ext eq $search_ext || lc($ext) eq $search_ext) {
		return $mimetype;
	    }
	}
    }
    "application/octet-stream";
}

1;

__END__

=head1 NAME

WE::Util::MIME - MIME support functions

=head1 SYNOPSIS

    use WE::Util::MIME qw(get_mime_type_by_filename %mime_types)

=head1 DESCRIPTION

=over

=item get_mime_type_by_filename($filename)

Return the MIME type for the supplied file. This function is exported
by default.

=item %mime_types

This is a hash of MIME type => array of extensions. This hash can be
exported optionally.

=cut

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2002,2003 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

