# -*- perl -*-

#
# $Id: Htdig.pm,v 1.18 2006/12/01 10:12:56 cmuellermeta Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE_Frontend::Indexer::Htdig;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

## XXX Maybe some day ...
# sub new {
#     my $class = shift;
#     my(%args) = @_;
#     my $self = {};
#     if ($args{-searchengine}) {
# 	WEsiteinfo::SearchEngine
#     }
# }

sub conf {
    my($conf, $lang) = @_;
    $conf =~ s/%\{lang\}/$lang/g;
    $conf;
}

sub conf_is_lang_dependent {
    my($conf) = @_;
    $conf =~ /%\{lang\}/ ? 1 : 0;
}

sub search {
    my(%args) = @_;
    my $words = delete $args{-words} || die "No words specified";
    my $conf  = delete $args{-conf};
    my $lang  = delete $args{-lang};
    my $query = delete $args{-query};
    my $debug = delete $args{-debug};
    my $https_hack = delete $args{-httpshack};
    my $transform  = delete $args{-transform};
    my $method = delete $args{-method};

    if (keys %args) { warn "Unknown arguments: " . join(", ", %args) } # XXXdie?

    local %ENV = %ENV;
    delete $ENV{REQUEST_METHOD}; # security barrier in htsearch
    # Location of htdig in the standard FreeBSD port, after a normal
    # unaltered install and a Debian 3.0 install. Sometimes $ENV{PATH} is
    # empty, so supply additional reasonable defaults.
    local $ENV{PATH} .= ":/usr/local/share/apache/cgi-bin:/opt/www/cgi-bin:/usr/lib/cgi-bin:/usr/bin:/bin";

    if ($debug) {
	warn "Current path is $ENV{PATH}";
    }

    require CGI;
    my $q = CGI::new($query);
    $q->param("words", $words);
    $q->param("format", "perl");
    $q->param("method", $method) if defined $method;

    my $conf_path = conf($conf, $lang) if defined $conf;
    my @htsearch_cmd = ("htsearch",
			(defined $conf ? ("-c", $conf_path) : ()),
			$q->query_string);
    open(HTSEARCH, "-|") or do {
	if ($debug) {
	    warn "Execute: @htsearch_cmd";
	}
	exec @htsearch_cmd;
	die "Can't execute htsearch command (@htsearch_cmd), PATH is $ENV{PATH}: $!";
    };

    # overread header
    while(<HTSEARCH>) {
	chomp;
	last if /^\r?$/;
    }

    # slurp generated perl data dump
    local $/ = undef;
    my $perlcode = <HTSEARCH>;
    #warn $perlcode;

    require Safe;
    my $cpt = Safe->new;
    my $obj = $cpt->reval($perlcode);

    my $nr = 0;
    die "Error while evaluating perl code result from htsearch call:\n@htsearch_cmd.\n" .
	"Code: " . join("\n", map { sprintf "%4d %s", ++$nr, $_ }
			split /\n/, $perlcode) . "\n" .
	"Error: $@\n" .
	(defined $conf ? "Configuration file is $conf_path\n" : "Using standard configuration file\n")
	    if !$obj;

    while(my($key,$val) = each %$obj) {
	if ($key =~ /(.*)_urlenc$/) {
	    my $real_key = $1;
	    $obj->{$real_key} = CGI::unescape($val);
	} elsif ($key eq 'list') {
	    for my $obj (@$val) {
		while(my($key,$val) = each %$obj) {
		    if ($key =~ /(.*)_urlenc$/) {
			$obj->{$1} = CGI::unescape($val);
		    }
		}
	    }
	}
    }

    my $parse_href = sub {
	my $href = shift;
	my($pageurl, $pagenumber);
	if (my($url, $querystring) = $href =~ /^(.*?)\?(.*)$/) {
	    my $q = CGI->new($querystring);
	    if (defined $lang && !defined $q->param("lang")) {
		$q->param("lang", $lang);
	    }
	    if (!defined $q->param("page")) {
		warn "Can't get page parameter from $href";
		$pagenumber = undef;
	    } else {
		$pagenumber = $q->param("page");
	    }
	    my $new_href = "$url?" . $q->query_string;
	    $pageurl = $new_href;
	} else {
	    warn "Can't parse URL $href";
	}
	($pageurl, $pagenumber);
    };

    if ($obj->{"pagelist"}) {
	my @pageurllist;
	my @pagenumberlist;
	my @hrefs = $obj->{"pagelist"} =~ m{href="(.*?)"}g;
	for my $href (@hrefs) {
	    my($pageurl, $pagenumber) = $parse_href->($href);
	    if (defined $pageurl) {
		push @pageurllist, $pageurl;
		push @pagenumberlist, $pagenumber;
	    }
	}
	# Add this page
	if ($pagenumberlist[0] != 1) {
	    unshift @pageurllist, undef; # undef means: this page
	    unshift @pagenumberlist, 1;
	} else {
	SEARCH: {
		for my $i (0 .. $#pagenumberlist) {
		    if ($i+1 != $pagenumberlist[$i]) {
			# current page is in the middle of the list
			splice @pagenumberlist, $i, 0, $i+1;
			splice @pageurllist, $i, 0, undef;
			last SEARCH;
		    }
		}
		# otherwise it's the last page
		push @pageurllist, undef;
		push @pagenumberlist, $#pagenumberlist+2;
	    }
	}
	$obj->{pageurllist}    = \@pageurllist;
	$obj->{pagenumberlist} = \@pagenumberlist;
    }

    for my $dir (qw(prev next)) {
	if ($obj->{$dir."page"}) {
	    my($href) = $obj->{$dir."page"} =~ m{href="(.*?)"};
	    my($pageurl, $pagenumber) = $parse_href->($href);
	    if (defined $pageurl) {
		$obj->{$dir."pageurl"} = $pageurl;
		$obj->{$dir."pagenumber"} = $pagenumber;
	    }
	}
    }

    if ($https_hack && $obj->{list}) {
	for my $hit (@{ $obj->{list} }) {
	    $hit->{url} =~ s{^http://}{https://};
	}
    }

    # words is documented, but not available?
    if (!exists $obj->{words}) {
	$obj->{words} = $words;
    }

    if ($transform) {
	$transform->($obj);
    }

    $obj;
}

sub generate_conf {
    my($c, %args) = @_;

    my $debug = $args{-debug};

    my $lang = $args{-lang};

    my $tpl  = $args{-htdigconftemplate} || $c->searchengine->htdigconftemplate;
    my $conf = $args{-htdigconf} || $c->searchengine->htdigconf;
    my $lang_conf = conf($conf, $lang);
    if (conf_is_lang_dependent($lang_conf)) {
	die "-lang should be supplied for language independent conf specification $conf";
    }

    if (!defined $tpl) {
	if ($debug) {
	    warn "No template config defined, we're done with $lang_conf.\n";
	}
	return $lang_conf;
    }

    my @dependents;
    if ($args{-dependents}) {
	@dependents = @{ $args{-dependents} };
    } else {
	(my $pkgfile = __PACKAGE__) =~ s{::}{/}g;
	# XXX what if module is named WEsiteinfo_project.pm and WEprojectinfo_project.pm?
	push @dependents,
	    $INC{"WEsiteinfo.pm"}, $INC{"WEprojectinfo.pm"},
	    $tpl,
	    $INC{"$pkgfile.pm"};
    }

    # is the configuration file current?
    my $conf_is_old = 0;
    if (!-e $lang_conf) {
	$conf_is_old = 1;
    } else {
	for my $dep (grep { defined $_ } @dependents) {
	    if (!-e $lang_conf || -M $dep < -M $lang_conf) {
		$conf_is_old = 1;
		last;
	    }
	}
    }

    if (!$conf_is_old) {
	warn "htdig config file $lang_conf is current, we're done.\n";
	return $lang_conf;
    }

    my $long_lang;
    if (defined $lang) {
	$long_lang = {en => "english",
		      de => "german",
		      it => "italian",
		      fr => "french",
		      kr => "korean",
		      ru => "russian",
		      es => "spanish",
		      pt => "portugese",
		      hu => "hungarian",
		     }->{$lang};
	warn "long_lang is not defined for $lang"
	    if !defined $long_lang;
    }

    # regenerate conf file
    require Template;
    # XXX Don't duplicate this --- already found in we_search.cgi and
    # we_redisys.cgi
    my $t = Template->new
	(ABSOLUTE => 1,
	 POST_CHOMP => 0,
	 INCLUDE_PATH => [$c->paths->site_templatebase,
			  $c->paths->we_templatebase,
			 ],
	 EVAL_PERL => 1,
	 PLUGIN_BASE => ["WE_" . $c->project->name . "::Plugin",
			 "WE_Frontend::Plugin"]
	);
    if ($debug) {
	warn "Create config file $lang_conf from $tpl.\n";
    }
    my $conf_header = <<EOF;
# DO NOT EDIT THIS FILE!
# Generated automatically by:
#   module: @{[ __PACKAGE__ ]}
#   user:   @{[ (getpwuid($<))[0] ]}
#   date:   @{[ scalar localtime ]}
EOF
    $t->process
	($tpl,
	 {c        => $c,
	  config   => $c, # for compatibility
	  lang     => $lang,
	  longlang => $long_lang,
	  # strip dash from args keys
	  args     => [map { (substr($_, 1) => $args{$_}) } keys(%args)],
	  conf_header => $conf_header,
	 }, $lang_conf)
	or die $t->error;

    return $lang_conf;
}

1;

__END__

=head1 NAME

WE_Frontend::Indexer::Htdig - interface to the htdig search engine

=head1 SYNOPSIS

    use WE_Frontend::Indexer::Htdig;
    my $results = WE_Frontend::Indexer::Htdig::search(-words => "word");

=head1 DESCRIPTION

This is an interface to the C<htdig> search engine. The result of the
C<search> function call is a perl hash reference containing the
results.

=head1 FUNCTIONS

=head2 search(%args)

Arguments are:

=over

=item -words

A string with the words to search. Multiple words are
space-separated. This argument is required.

=item -conf

Specify a different htdig configuration file, otherwise the default
C<htdig.conf> is used.

=item -lang

(Optional) Specify a language. The configuration parameter given by
conf may contain %{lang} placeholders which are substituted by the
value of this argument.

=item -debug

Output some diagnostics to stderr.

=item -httpshack

Set to a true value if operating on a https server. htdig does not
handle SSL, so a parallel http should be setup for the indexing. With
the https hack the URLs in the search result C<list> are translated at
template display time.

=back

The result is a hash reference with the following keys:

=over

=item logical_words

=item matches_per_page

=item max_stars

=item page

=item pages

=item list

Holds an array with the search results. See below.

=item nomatch

This variable is set to a true value if the search produces no
results. Also detectable by an empty result list.

=item pageurllist

A list of URLs for the 1 .. 10 result pages.

=item pagenumberlist

The corresponding numbers for the pageurllist. Please note that
perl/Template arrays start with index 0 (which would be page 1).

=item prevpageurl

=item nextpageurl

Hold the URLs for the previous resp. next result page.

=item prevpagenumber

=item nextpagenumber

Usually not needed: the number of the previous resp. next result page.
In fact you would label them "Prev"/"Next" or "E<lt>"/"E<gt>".

=item ...

=back

There are more keys. For a complete list refer to the htdig
documentation at L<http://www.htdig.org>, C<htsearch>, Templates. Note
that the original template variable names are converted to lowercase.

The value of C<list> is an array reference with the matches. Each
match is a hash reference with the following keys:

=over

=item url

The URL of the page. See also the C<-httpshack> option above.

=item title

The title of the page, as specified by the <title> html tag.

=item anchor

=item excerpt

The first lines of text in the document.

=item score

=item percent

=item modified

The date and time the document was last modified. See also the
documentation of the C<iso_8601> config variable in C<htdig.conf>.

=item ...

=back

The complete list is also in the htdig documentation at
L<http://www.htdig.org>, C<htsearch>, Templates.

=head1 CONFIGURATION FILES

It is best to just use the original C<conf/htdig.tpl.conf> file found
in the B<webeditor> distribution. The indexing program in B<webeditor>
will use the template file and fill it with the configuration found in
C<WEsiteinfo>. Please look also into htdig.txt in the webeditor/doc
directory for a first-time installation/configuration.

=head2 WEsiteinfo configuration:

To override the searchindexer path (default is "rundig" without a
path):

    $searchengine->searchindexer("/usr/local/bin/rundig");

To set the template htdig and target htdig configuration files (these
settings are highly recommended):

    $searchengine->htdigconftemplate($paths->uprootdir . "/conf/htdig.tpl.conf");
    $searchengine->htdigconf($paths->uprootdir . "/conf/htdig.%{lang}.conf");

where C<$paths> is the B<WEsiteinfo::Paths> object documented in
L<WE_Frontend::Info>. If the configuration file should not be language
dependent, then use

    $searchengine->htdigconf($paths->uprootdir . "/conf/htdig.conf");

instead.

=head2 Own htdig.conf

If you decide to make your own C<htdig.conf>, put at least the
following lines into the configuration file:

    template_map: Long long ${common_dir}/long.html \
                  Short short ${common_dir}/short.html \
                  Perl perl ${common_dir}/perl/match.pl
    template_name: perl
    search_results_header: ${common_dir}/perl/header.pl
    search_results_footer: ${common_dir}/perl/footer.pl
    nothing_found_file:    ${common_dir}/perl/nomatch.pl

C<${common_dir}/perl> should be a link to the directory
C<.../lib/WE_Frontend/Indexer/htdig_common>.

=head1 INSTALLING HTDIG

htdig is available e.g. from this location:
L<http://www.htdig.org/files/snapshots/htdig-3.2.0b5-20040404.tar.gz>.

To compile and install htdig from scratch, the following configure
line could be used to create a path layout similar to the RedHat one:

    sh configure --prefix=/usr --with-search-dir=/usr/share/htdig --with-image-dir=/usr/share/htdig --with-cgi-bin-dir=/usr/bin --with-config-dir=/etc --with-database-dir=/usr/share/htdig

=head1 CAVEATS

Many. Mind the permissions. Especially, rundig may use the default
database directory (C</usr/local/share/htdig/database> or such) as the
temporary directory for sorting, which will fail if the apache user
(usually C<nobody> or C<www>) has no permissions to write to this
directory. In this case change the C<TMPDIR> definition in rundir or
set appropriate write permissions.

=head1 AUTHOR

Slaven Rezic - slaven@rezic.de

=head1 SEE ALSO

L<htdig(1)>.

=cut

