package WE_Frontend::Info;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

######################################################################
package WEsiteinfo::Paths;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(scheme servername serverport absoluteurl
			     livescheme liveservername liveserverport
			     liveabsoluteurl
			     hosturl livehosturl
			     uprootdir liveuprootdir
			     rooturl rootdir cgiurl cgidir
			     liverooturl liverootdir livecgiurl livecgidir
			     we_templatebase site_we_templatebase
			     site_templatebase we_htmldir we_htmlurl
			     we_datadir photodir
			     pubhtmldir prototypedir
			     htuser htpassword
			    ));
# backward compat:
*we_htmlbase = \&we_htmldir;
*we_database = \&we_datadir;

sub new { bless {}, shift } # XXX this used to be __PACKAGE__ --- document!

# Provide sensible defaults
my %paths_constructed_member =
    (hosturl         => sub { $_[0]->scheme . "://" .
			      $_[0]->servername .
			      (defined $_[0]->serverport && $_[0]->serverport ne "80"
			       ? ":" . $_[0]->serverport
			       : "")
			  },
     livehosturl     => sub { $_[0]->livescheme . "://" .
			      $_[0]->liveservername .
			      (defined $_[0]->liveserverport && $_[0]->liveserverport ne "80"
			       ? ":" . $_[0]->liveserverport
			       : "")
			  },
     absoluteurl     => sub { $_[0]->hosturl . $_[0]->rooturl },
     liveabsoluteurl => sub { $_[0]->livehosturl . $_[0]->liverooturl },
     rooturl         => sub { "" },
     rootdir         => sub { $_[0]->uprootdir . "/htdocs" },
     liverooturl     => sub { "" },
     liverootdir     => sub { $_[0]->liveuprootdir . "/htdocs" },
     cgiurl          => sub { "/cgi-bin" },
     cgidir          => sub { $_[0]->uprootdir . "/cgi-bin" },
     livecgiurl      => sub { $_[0]->cgiurl },
     livecgidir      => sub { $_[0]->liveuprootdir . "/cgi-bin" },
     we_htmldir      => sub { $_[0]->rootdir . "/we" },
     we_htmlurl      => sub { $_[0]->rooturl . "/we" },
     we_templatebase => sub { $_[0]->we_htmldir . "/we_templates" },
     site_templatebase    => sub { $_[0]->we_htmldir . "/" .
				   $_[0]->{_parent}->project->name .
				   "_templates" },
     site_we_templatebase => sub { $_[0]->we_htmldir . "/" .
				   $_[0]->{_parent}->project->name .
				   "_we_templates" },
     prototypedir    => sub { $_[0]->we_htmldir . "/" .
			      $_[0]->{_parent}->project->name .
			      "_prototypes" },
     photodir        => sub { $_[0]->rootdir . "/photos" },
     pubhtmldir      => sub { $_[0]->rootdir },
     we_datadir      => sub { $_[0]->uprootdir . "/we_data" },
     scheme          => sub { "http" },
     livescheme      => sub { "http" },
    );
sub get {
    my($self, $key) = @_;
    if (!defined $self->{$key} && exists $paths_constructed_member{$key}) {
	$paths_constructed_member{$key}->($self);
    } else {
	$self->SUPER::get($key);
    }
}

######################################################################
package WEsiteinfo::SearchEngine;
use base qw(Class::Accessor);
# prelive_htdigconf and live_htdigconf is obsolete
__PACKAGE__->mk_accessors(qw(searchindexer htdigconf htdigconftemplate
			     prelive_htdigconf live_htdigconf
			     use_prelive_database));
sub new { bless {}, shift }

# Provide sensible defaults
my %searchengine_constructed_member =
    (searchindexer   => sub { "rundig" }, # XXX or htdig?
    );
sub get {
    my($self, $key) = @_;
    if (!defined $self->{$key} && exists $searchengine_constructed_member{$key}) {
	$searchengine_constructed_member{$key}->($self);
    } else {
	$self->SUPER::get($key);
    }
}

######################################################################
package WEsiteinfo::Staging;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(transport user password host directory
			     cgidirectory tempdirectory temp2directory
			     stagingext rsakey archivefile message));
sub new { bless {}, shift }

# Provide sensible defaults
my %staging_constructed_member =
    (directory       => sub { $_[0]->{_parent}->paths->liverootdir },
     cgidirectory    => sub { warn $_[0]->{_parent}->paths->livecgidir; $_[0]->{_parent}->paths->livecgidir },
    );
sub get {
    my($self, $key) = @_;
    if (!defined $self->{$key} && exists $staging_constructed_member{$key}) {
	$staging_constructed_member{$key}->($self);
    } else {
	$self->SUPER::get($key);
    }
}

######################################################################
package WEsiteinfo::Siteext;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(external_auth notify_mailer notify_background));
sub new { bless {}, shift }

######################################################################
package WEprojectinfo;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(name longname
			     sitelanguages editorlanguages pagetypes
			     defaulteditorlang cookieexpirationtime
			     productname templatefortype labelfortype
			     imagetypes imagesubtypes
			     iconfortype features projectext
			     class feclass
			     stagingexcept stagingexceptpat stagingextracgi
			     stagingadditional
			     adminmail developermail
			     sessionlocking useversioning
			     standardext
			    ));
sub new { bless {}, shift }

# Provide sensible defaults
my %projectinfo_constructed_member =
    (productname       => sub { "web.editor" },
     editorlanguages   => sub { [qw(de en)] },
     defaulteditorlang => sub { $_[0]->editorlanguages->[0] },
     cookieexpirationtime => sub { '+1d' },
     developermail     => sub { 'eserte@users.sourceforge.net' },
     standardext       => sub { ".html" }
    );

sub get {
    my($self, $key) = @_;
    if (!defined $self->{$key} && exists $projectinfo_constructed_member{$key}) {
	$projectinfo_constructed_member{$key}->($self);
    } elsif ($key eq 'features' && !exists $self->{features}) {
	return {};
    } elsif ($key eq 'longname' && !exists $self->{longname}) {
	return $self->{name};
    } elsif ($key =~ /^(?:sessionlocking|useversioning)$/) {
	return $self->get("features")->{$key};
    } else {
	$self->SUPER::get($key);
    }
}

sub set {
    my($self, $key, $val) = @_;
    if ($key =~ /^(?:sessionlocking|useversioning)$/) {
	return $self->{features}{$key} = $val;
    } else {
	$self->SUPER::set($key, $val);
    }
}

######################################################################
package WEsiteinfo;
use base qw(Exporter Class::Accessor);
__PACKAGE__->mk_accessors(qw(project paths searchengine staging debug siteext
			     liveconfig preliveconfig));
sub new { bless {}, shift }
@WEsiteinfo::EXPORT_OK = qw($c);

my %subobject = qw(project 1 paths 1 searchengine 1 staging 1 siteext 1);
sub set {
    my($self, $key, $val) = @_;
    if (exists $subobject{$key} && UNIVERSAL::isa($val, 'HASH')) {
	# provide "backlink" to parent object
	$val->{_parent} = $self;
    }
    $self->SUPER::set($key, $val);
}

1;

__END__

=head1 NAME

WE_Frontend::Info - classes for the new WEsiteinfo.pm config file

=head1 SYNOPSIS

    use WE_Frontend::Info;
    $paths = bless {}, "WEsiteinfo::Paths";
    ...

=head1 DESCRIPTION

XXX Maybe this should go to webeditor/doc/configuration.pod?

This package holds the classes for the WEsiteinfo.pm configuration
file. Please consult the source code for a list of classes and
members.

=head2 CONFIGURATION MEMBERS

=head3 paths (B<WEsiteinfo::Paths>)

=over

=item scheme

The protocol scheme for the editor site. Usually "http" or "https".
The default is "http".

=item livescheme

The protocol scheme for the live site. This may differ from the
"scheme". The default is "http".

=item servername

The name of the server for the editor site.

=item liveservername

The name of the server for the live site.

=item serverport

The port of the server for the editor site. There is no default value.

=item liveserverport

The port of the server for the live site.

=item uprootdir

The filesystem path of the directory which contains the C<htdocs>,
C<cgi-bin> and other directories. This is the "real" root of the
system.

=item rooturl

The webserver root of the editor site, usually "/".

=item liverooturl

The webserver root of the live site.

=item rootdir

The filesystem path to the C<htdocs> directory of the editor site.
This is by default the "htdocs" subdirectory of the uprootdir.

=item liverootdir

The filesystem path to the C<htdocs> directory of the live site.

=item absoluteurl

C<scheme>, C<servername>, C<serverport> and C<rooturl> of the editor
site combined to an absolute url.

=item liveabsoluteurl

The same as absoluteurl for the live site.

=item cgiurl

The relative URL to the cgi-bin directory on the editor site. By
default this is "/cgi-bin".

=item livecgiurl

The relative URL to the cgi-bin directory on the live site.

=item cgidir

The filesystem path to the cgi-bin directory on the editor site. By
default this is the "cgi-bin" subdirectory of uprootdir.

=item livecgidir

The filesystem path to the cgi-bin directory on the live site. By
default this is the "cgi-bin" subdirectory of uprootdir.

=back

There are more configuration variables for paths to change, but these
are rarely needed. Consult the source for a complete list.

=head3 searchengine (B<WEsiteinfo::SearchEngine>)

=head3 staging (B<WEsiteinfo::Staging>)

=head3 debug

=head3 siteext (B<WEsiteinfo::Siteext>)

=head3 project (B<WEprojectinfo>)

=cut
