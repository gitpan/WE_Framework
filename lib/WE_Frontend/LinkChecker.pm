# -*- perl -*-

#
# $Id: LinkChecker.pm,v 1.7 2003/12/16 15:21:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Online Office Berlin. All rights reserved.
# Copyright (C) 2002,2003 Slaven Rezic.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.

#
# Mail: slaven@rezic.de
# WWW:  http://we-framework.sourceforge.net
#

package WE_Frontend::LinkChecker;

use HTML::LinkExtor;
use URI;
use LWP::UserAgent;

use strict;
use vars qw($VERSION $VERBOSE);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(Restrict Follow Url Pending SeenOk SeenError Ua));

sub new {
    my($class, %args) = @_;
    my $self = {};
    bless $self, $class;

    $self->Follow(undef);
    $self->Restrict(undef);
    while(my($k,$v) = each %args) {
	$self->{ucfirst(substr($k,1))} = $v;
    }
    $self->SeenOk({});
    $self->SeenError({});
    $self->Pending([]);
    $self;
}

sub get_all_urls {
    my $self = shift;
    if (ref $self->Url eq 'ARRAY') {
	@{$self->Url};
    } else {
	$self->Url;
    }
}

sub check_html {
    my($self) = @_;
    my $html = "";
    $html .= "<h1>Linkcheck results</h1>";
    $html .= "<h2>Configuration</h2>";
    $html .= $self->check_html_header;

    my %fail_urls = $self->check;
    $html .= "<h2>Link errors</h2>";
    if (%fail_urls) {
	foreach my $caller (sort keys %fail_urls) {
	    $html .= $self->output_failed_url_as_html($caller, $fail_urls{$caller});
	}
    } else {
	$html .= "None.<p>\n";
    }
    $html .= "<a href='javascript:history.back()'>Back</a>";
    $html;
}

sub check_tt {
    my($self, $tt, $template, $extra_args) = @_;
    my $html;
    $tt->process($template, { self => $self,
			      fail_urls => { $self->check },
			      ($extra_args ? %$extra_args : ()),
			    }, \$html)
	or die $tt->error;
    $html;
}

sub check_html_header {
    my $self = shift;
    my $html = "";
    $html .= "Checked start URLs:<br><ul>\n";
    foreach my $url ($self->get_all_urls) {
	$html .= "<li> <a href=\"$url\">$url</a>\n"; # XXX escape
    }
    $html .= "</ul>\n";

    $html .= "Restrict to:<br><ul>\n";
    if (!$self->Restrict) {
	$html .= "<li> none\n";
    } else {
	foreach my $url (@{ $self->Restrict }) {
	    $html .= "<li> $url\n"; # XXX escape
	}
    }
    $html .= "</ul>\n";

    $html .= "Follow:<br><ul>\n";
    if (!$self->Follow) {
	$html .= "<li> all non-restricted\n";
    } else {
	foreach my $url (@{ $self->Follow }) {
	    $html .= "<li> $url\n"; # XXX escape
	}
    }
    $html .= "</ul>\n";
    $html;
}

sub output_failed_url_as_html {
    my($self, $caller, $failures) = @_;
    my $html = "<h2>" . _we_page_link($caller) . "</h2>\n<ul>";
    foreach my $fail_url (sort keys %$failures) {
	$html .= "<li>" . _we_failed_page($fail_url) . " (Error: @{[ $self->SeenError->{$fail_url}->{Code} ]})\n"; # XXX HTML escape
    }
    $html .= "</ul>\n";
    $html;
}

sub _we_failed_page {
    my $url = shift;
    # XXX lang-dependent strings
    if ($url =~ m|/images/|) {
	"internal image ($url)";
    } elsif ($url =~ m|/(site_)?photos/|) {
	"embedded photo ($url)";
    } elsif ($url =~ m|/videos/|) {
	"video link ($url)";
    } elsif ($url =~ m|/download/|) {
	"download link ($url)";
    } elsif ($url =~ m|/headlines/|) {
	"headline image ($url)";
    } else {
	$url;
    }
}

# XXX do not hardcode any code or URLs!!!
sub _we_page_link {
    # XXX html escape
    my $url = shift;
    if ($url =~ m|/html/[^/]+/(\d+)\.html$|) {
	my $id = $1;
	q{<a target="_blank" href="}.$url.q{">}.$url.q{</a> (<a target="_blank" href="http://$ENV{SERVER_NAME}/cgi-bin/we_redisys.cgi?pageid=}.$id.q{&goto=pageeditorframe">EDIT</a>)};
	## XXX opener geht nach dem ersten Mal verloren
	#q{<a href="#" onclick="opener.top.location.href = 'http://mom.intra.onlineoffice.de/~eserte/sample/wwwroot/cgi-bin/we_redisys.cgi?pageid=}.$id.q{&goto=pageeditorframe'; return false;">}.$url.q{</a>};
	## der ursprüngliche Frameaufbau ist nicht mehr da
	#q{<a href="#" onclick="opener.top.frames['cms_explorer_js'].action('} . $id . q{','cms_explorer_js','','edit','',''); return false;" onmouseover="window.status='edit page with id } . $id . q{'; return true;">} . $url . q{</a>};
    } elsif ($url eq 'START') {
	$url;
    } else {
	"<a href=\"$url\">$url</a>";
    }
}

sub check {
    my $self = shift;
    my(%args) = @_;

    my %fail_urls;
    foreach my $url ($self->get_all_urls) {
	push @{ $self->Pending }, {Url => $url,
				   Caller => "START"};
    }

    if (!$self->Ua) {
	$self->Ua(LWP::UserAgent->new);
	$self->Ua->timeout(10);
	$self->Ua->env_proxy;
    }
    while(@{ $self->Pending }) {
	my $o = shift @{ $self->Pending };
	my $new_url = $o->{Url};
	my $caller = $o->{Caller};

	# Check whether already checked
	if ($self->SeenError->{$new_url}) {
	    $fail_urls{$caller}->{$new_url}++;
	    next;
	}
	next if ($self->SeenOk->{$new_url});

	warn "Check $new_url...\n" if $VERBOSE;
	if ($self->_restricted($new_url)) {
	    warn "$new_url is restricted\n" if $VERBOSE;
	    next;
	}
	my $failure = $self->_check($new_url);
	if ($failure) {
	    $fail_urls{$caller}->{$new_url}++;
	    $self->SeenError->{$new_url} = $failure;
	} else {
	    $self->SeenOk->{$new_url}++;
	}
    }
    %fail_urls;
}

sub _check {
    my($self, $url) = @_;
    $url = _canonize_url($url);

    if ($self->_nofollow($url)) {
	my $res = $self->Ua->request(HTTP::Request->new(HEAD => $url));
	if ($res->is_error) {
	    warn "$url returned @{[ $res->code ]}\n" if $VERBOSE;
	    return { Code => $res->code,
		     Error => $res->message };
	}
	warn "Do not follow $url\n" if $VERBOSE;
	return;
    }

    my $p = HTML::LinkExtor->new;
    my $res = $self->Ua->request(HTTP::Request->new(GET => $url),
				 sub {$p->parse($_[0])});
    if ($res->content_type ne 'text/html') {
	warn "$url is not text/html\n" if $VERBOSE;
	return;
    }
    if ($res->is_error) {
	warn "$url returned @{[ $res->code ]}\n" if $VERBOSE;
	return { Code => $res->code,
		 Error => $res->message };
    }

    my $base = $res->base;

    my %links;
    foreach my $e ($p->links) {
	for(my $i=2; $i<=$#$e; $i+=2) {
	    next if $e->[$i] =~ /^javascript:/;
	    my $checkurl = _canonize_url(URI->new_abs($e->[$i], $base)->as_string);
	    $links{$checkurl}++;
	}
    }
    push @{ $self->Pending}, map { +{Url => $_, Caller => $url} }
	                         sort keys %links;
    undef;
}

sub _canonize_url {
    my $url = shift;
    $url =~ s/\#.*//; # XXX better way?
    $url;
}

sub _restricted {
    my($self, $url) = @_;
    return 0 if !$self->Restrict;
    foreach my $restr (@{ $self->Restrict }) {
	return 0 if $url =~ /$restr/;
    }
    1;
}

sub _nofollow {
    my($self, $url) = @_;
    return 0 if !$self->Follow;
    foreach my $restr (@{ $self->Follow }) {
	return 0 if $url =~ /$restr/;
    }
    1;
}

1;

__END__

=head1 NAME

WE_Frontend::LinkChecker - check a site for broken links

=head1 SYNOPSIS

    use WE_Frontend::LinkChecker;
    my $lc = WE_Frontend::LinkChecker->new(-url => "http://www/",
					   -restrict => [...]);
    my $errors = $lc->check_html;
    print $errors;

=head1 DESCRIPTION

=over

=item new(-url => $url, -restrict => $restrict_array)

Construct a new C<WE_Frontend::LinkChecker> object. The default start
URL is C<$url>, the restrictions are specified by C<-restrict>.

=item check_html

Start the linkcheck process and return the results as a HTML string.

=item check_html_header

Return the HTML header. This method is used by C<check_html> by
default.

=item check_tt($template_object, $template_file, $extra_args)

Start the linkcheck process and create the output string with the help
of Template-Toolkit. The C<Template> object is set in
C<$template_object>. C<$template_file> holds the C<Template> file.
Extra arguments for the C<process> method of C<Template> as a hash
reference may also be supplied.

=item check

Start the linkcheck process and return the list of failed_urls as a
hash.

=back

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<LWP::UserAgent>.

=cut
