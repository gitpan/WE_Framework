# -*- perl -*-

#
# $Id: OldController.pm,v 1.84 2005/02/23 13:13:59 eserte Exp $
#
# WebEditor::OldController used to be we_redisys.cgi in the old web.editor
# system.
#
# Original author:
#	oleberlin@users.sourceforge.net
# Modified into a OO module and current maintainer:
#	eserte@users.sourceforge.net
#
# See http://www.sourceforge.net/projects/we-framework
#
# Copyright (c) 1999-2002 Olaf Maetzner. All rights reserved.
# Copyright (c) 1999-2005 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#

package WebEditor::OldController;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.84 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(R C Class FE_Class HeaderPrinted
			     SessionName Session Goto Messages
			     EditorLang TemplateVars TemplateConf Root FE
			     ContentDumper ScriptDumper User Password
			     CustomUserDB
			    ));
use CGI qw(:standard);

use WE::Util::LangString qw(langstring new_langstring set_langstring);

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::import = sub { };
	*warnings::unimport = sub { };
    }
}
{
    ## XXX This should go to the original Data::JavaScript!!!
    use Data::JavaScript;
    package Data::JavaScript;
no warnings 'redefine';
my $unicoderange = '\x{0100}-\x{fffd}';
if ($] < 5.006) { $unicoderange = "" }
sub quotemeta {
	my $text = shift;
	$text =~ s/([^\x20\x21\x23-\x26\x28-\x7E$unicoderange])/sprintf("\\%03o", ord($1))/geo;
	$text =~ s/([$unicoderange])/sprintf("\\u%04x", ord($1))/geo;
	$text;
}
}

{
    if (eval q{ use CGI::Util; 1 }) {
	package CGI::Util;
	no warnings 'redefine';
	if (prototype(\&CGI::Util::utf8_chr) eq '$') {
	    *utf8_chr = sub ($) {
		chr($_[0]);
	    };
	} else {
	    *utf8_chr = sub {
		chr($_[0]);
	    };
	}
    }
}

sub subs {
    # where do you want to go today ;-)

    my %admin_pages = map { ($_ => [$_, "WebEditor::OldController::Admin"]) }
	(qw(admin publish linkchecker checkreleased releasepages useradmin));

    +{'login'            => "login",
      'pageeditorframe'  => "pageeditorframe",
      'mainframe' 	 => "mainframe",
      'mainpanel'	 => "mainpanel",
      'siteeditorframe'  => "siteeditorframe",
      'main'             => "siteeditorframe", # just an alias
      'pageedit'         => "pageedit",
      'siteedit'         => "siteedit",
      'siteeditexplorer' => "siteeditexplorer",
      'folderedit'       => "folderedit",
      'doctreeframe'     => "doctreeframe",
      'doctree'          => "doctree",
      'preview'          => "preview",
      'updatehtml'       => "updatehtml",
      'search'           => "search",
      'error'            => "error",
      'savepage'         => "savepage",
      'createpage'       => "createpage",
      'uploadpage'       => "uploadpage",
      'createfolder'     => "createfolder",
      'deletepage'       => "deletepage",
      'cancelpage'	 => "cancelpage",
      'showeditor'       => "showeditor",
      'movecopyframeset' => "movecopyframeset",
      'movecopyjs'       => "movecopyjs",
      'movecopyexplorer' => "movecopyexplorer",
      'movecopyaction'   => "movecopyaction",
      'unlock'           => "unlock",
      'passthroughdb'    => "passthrough", # like passthrough with DB access

      # mixin'ed:
      'systemexplorer'   => "systemexplorer",
      'wwwauthedit'      => "wwwauthedit",

      %admin_pages,
     };
}

sub showeditor_methods {
    +{
      "image"      => "showeditor_any",
      "download"   => "showeditor_any",
      "link"       => "showeditor_link",
      "teaserlink" => "showeditor_teaserlink",
     };
}

sub new {
    my($class) = @_;
    my $self = bless {}, $class;
    $self;
}

sub handle {
    my($self, $c, $r) = @_;
    my $ret = $self->init($c, $r);
    return if !$ret;
    $self->dispatch;
}

# The output of templateconf is a hash ref. The method can be overridden to
# add other options to this hash, e.g. FILTERS => { filter => coderef }
sub templateconf {
    my $self = shift;
    my $c = $self->C;

    my $template_compile_dir = "/tmp/webeditor-cache-$<";
    if (!-e $template_compile_dir) {
	mkdir $template_compile_dir, 0700;
	if (!-e $template_compile_dir) {
	    undef $template_compile_dir;
	    warn "Can't create $template_compile_dir, disabled caching...";
	}
    } else {
	if (!-d $template_compile_dir) {
	    undef $template_compile_dir;
	    warn "$template_compile_dir is not a directory, disabled caching...";
	}
    }

    return {ABSOLUTE => 1,
	    POST_CHOMP => 1,
	    INCLUDE_PATH => [$c->paths->site_templatebase,
			     $c->paths->we_templatebase,
			    ],
	    EVAL_PERL => 1,
	    PLUGIN_BASE => ["WE_" . $c->project->name . "::Plugin",
			    "WE_Frontend::Plugin"],
	    #ERROR => "we_error.tpl.html",# worse diagnostics...
	    #DEBUG => "all",
	    (defined $template_compile_dir ?
	     (COMPILE_EXT => ".ttc",
	      COMPILE_DIR => $template_compile_dir,
	     ) : ()
	    ),
	   };
}

sub init {
    my($self, $c, $r, %args) = @_;

    my $batch = delete $args{-batch} || 0;
    if ($batch) {
	while(my($k,$v) = each %args) {
	    param(substr($k,1), $v);
	}
    }

    $self->R($r);
    $self->C($c);

    $self->Class   ($c->project->class);
    $self->FE_Class($c->project->feclass);

    $self->Messages({});
    $self->CustomUserDB({});
    $self->HeaderPrinted(0);
    $self->SessionName('we_session_' . $c->project->name);
    my $session = $self->Session({ cookie($self->SessionName) });
    my $editorlang = param('editorlang')      ||
		     $session->{'editorlang'} ||
		     $c->project->defaulteditorlang;
    my $scriptname = ($ENV{MOD_PERL} && $self->R ? $self->R->uri : script_name());
    $editorlang =~ s/\W//g; # make safe characters
    $self->EditorLang($editorlang);
    $self->TemplateVars
	({c	      => $c,
	  config      => $c, # backward compatibility
	  editorlang  => $self->EditorLang,
	  # for convenience:
	  cgiurl      => $c->paths->cgiurl,
	  rooturl     => $c->paths->rooturl,
	  paths       => $c->paths,
	  productname => $c->project->productname,
	  debug       => $c->debug,
	  scriptname  => $scriptname,
	  controller  => $self,
	 });

    $self->TemplateConf($self->templateconf);

    local $| = 1;

    my $goto = param("goto");
    $self->Goto($goto);
    if (defined $goto && $goto =~ /^passthrough(site)?$/) {
	if ($goto eq 'passthrough') {
	    $self->passthrough;
	} else {
	    $self->passthroughsite;
	}
	return 0;
    }

    if (($c->siteext && $c->siteext->external_auth)) {
	my $user = remote_user();
	if (defined $user && $user eq "logoutuser") {
	    if (defined $goto && $goto eq "logout") {
		$self->logout;
		return 0; # no dispatch
	    } else {
		print redirect($c->paths->scheme . '://invalid@' . $c->paths->servername . ":" . $c->paths->serverport . $scriptname);
		return 0;
	    }
	}
    }

    my $root = $self->Class->new(-rootdir => $c->paths->we_database,
				 -locking => 1,
				 -connect => exists $ENV{MOD_PERL} ? 0 : 1,
				);
    $self->Root($root);
    my $fe = $self->FE_Class->new(-root => $root, -config => $c);
    $self->FE($fe);

    $c->debug(1) if (param('debug'));

    # set some values from session or defaultvalues
    my($user, $password, $got_user_password);
    if ($c->project->features->{session} && $session->{'sid'}) {
	my $sess = $self->get_session($session->{sid});
	$user     = $sess->{user};
	$password = $sess->{password};
	$got_user_password = 1;
    } else {
	$user     = param('user')     || $session->{'user'}     || "";
	$password = param('password') || $session->{'password'} || "";
	$got_user_password = param('user') && (!$session->{'user'} || $session->{'user'} ne param('user'));
    }
    $self->User($user);
    $self->Password($password);

    if ($got_user_password) {
	$root->login($user, $password);
    }

    if (!$batch && !($c->siteext && $c->siteext->external_auth)) {
	if ($user =~ /^\s*$/ || $password =~ /^\s*$/) {
	    $self->login;
	    return 0;
	}
    }

    $self->TemplateVars->{is_allowed} = sub {
	return 1 if $batch;
	$self->identify;
	my $root = $self->Root;
	$root->is_allowed($_[0]);
    };

    if (defined $goto && $goto eq "logout") {
	$root->logout($user) if defined $user && $user ne "";
	$self->login;
	return 0; # no dispatch
    }
    if ($session->{sid} || $c->project->features->{session}) {
	my $sess = $self->get_session($session->{sid});
	$sess->{user}       = $user;
	$sess->{password}   = $password;
	$session->{editorlang} = $self->EditorLang; # XXX better store in %sess, but editorlang is used very early, see above...
	$session->{sid} = $sess->{_session_id};
    } else {
	$session->{'user'}       = $user;
	$session->{'password'}   = $password;
	$session->{'editorlang'} = $self->EditorLang;
    }
    my $cookie = cookie(-name    => $self->SessionName,
			-value   => $self->Session,
			-expires => $c->project->cookieexpirationtime || '+1d');
    $self->TemplateVars->{rootdb}    = $root;
    $self->TemplateVars->{objdb}     = $root->ObjDB;
    $self->TemplateVars->{username}  = $user;
    $self->TemplateVars->{'locking'} = $c->project->sessionlocking ? $user : "" ;

    $root->OnlineUserDB->ping($user) if $root->OnlineUserDB;

    my $content_dumper = $c->project->projectext && $c->project->projectext->{content_dumper};
    if (!$content_dumper) { $content_dumper = "WE_Content::PerlDD" }
    $self->ContentDumper($content_dumper);

    my $script_dumper = $c->project->projectext && $c->project->projectext->{script_dumper};
    if (!$script_dumper) { $script_dumper = "WE_Content::PerlDD" }
    $self->ScriptDumper($script_dumper);

    # print HTTP-header, set the cookies
    if (!$batch && !param("nohttpheader") && (!defined param("goto") || param("goto") ne 'preview')) {
	print $self->myheader(-cookie=> [$cookie]);
	$self->{HeaderPrinted} = 1;
    }

    1;
}

sub dispatch {
    my $self = shift;
    my $goto = $self->Goto;
    my $c    = $self->C;
    my $subs = $self->subs;

    {
	if (!defined $goto) {
	    if ($c->siteext && $c->siteext->external_auth) {
		$goto = "mainframe"; # already authenticated...
	    } else {
		$goto = "login";
	    }
	}
	my $method = $subs->{$goto};
	if (!defined $method) {
	    if ($c && $c->siteext && $c->siteext->external_auth) {
		if ($goto eq "logout") {
		    # XXX logout is not really possible with external_auth
		    # --- maybe remove the link from mainpanel?
		    return $self->logout;
		} else {
		    $method = $subs->{'mainframe'};
		}
	    } else {
		warn "goto $goto is unknown";
		$method = $subs->{'login'};
	    }
	}
	if (UNIVERSAL::isa($method, "ARRAY")) {
	    my $class;
	    ($method, $class) = @$method;
	    eval qq{ require $class }; die $@ if $@;
	}
	warn "goto: $goto (method $method)\n" if $c->debug;
	$self->$method();
    }

    die $@ if $@ and $c->debug;
}

sub myheader {
    my($self, %args) = @_;
    $args{-charset} = $self->output_charset if !exists $args{-charset};
    header(%args);
}

sub output_charset {
    "iso-8859-1"
}

sub get_fh_charset_converter {
    my $self = shift;
    my $output_charset = $self->output_charset;
    if ($output_charset eq "iso-8859-1") {
	# do nothing
	return sub { };
    }
    return sub {
	my $fh = shift;
	binmode($fh, ":encoding(" . $output_charset . ")");
    };
}

sub get_string_charset_converter {
    my $self = shift;
    my $output_charset = $self->output_charset;
    if ($output_charset eq "iso-8859-1") {
	# do nothing
	return sub { $_[0] };
    }
    require Encode;
    return sub {
	Encode::encode($output_charset, $_[0]);
    };
}

sub get_string_charset_decode_converter {
    my $self = shift;
    my $output_charset = $self->output_charset;
    if ($output_charset eq "iso-8859-1") {
	# do nothing
	return sub { $_[0] };
    }
    require Encode;
    return sub {
	Encode::decode($output_charset, $_[0]);
    };
}

sub reset_fh_charset_converter {
    my $self = shift;
    my $output_charset = $self->output_charset;
    if ($output_charset eq "iso-8859-1") {
	# do nothing
	return sub { };
    }
    return sub {
	my $fh = shift;
	binmode($fh, ":raw");
    };
}

######################################################################
#
# show login screen
#
sub login {
    my $self = shift;
    my $message = shift;
    if (!$self->HeaderPrinted) {
	# Create also a pseudo cookie for the cookie detection code in
	# LoginDispatcher.pm.
	print $self->myheader(-cookie => cookie(-name => $self->SessionName,
						-value => {}));
    }
    my $templatevars = $self->TemplateVars;
    my $c = $self->C;
    $templatevars->{'editorlanguages'} = $c->project->editorlanguages;
    if ($message) {
	$templatevars->{'login_message'} = $message;
    } elsif (param("message")) {
	$templatevars->{'login_message'} = param("message");
    }
    $self->_tpl("bestwe", "we_login_screen.tpl.html");
} #### sub login END

sub check_login {
    my $self = shift;
    $self->login unless $self->identify;
}

sub logout {
    my $self = shift;
    if (!$self->HeaderPrinted) {
	print $self->myheader(-cookie => undef);
    }

    my $session = $self->Session;
    my $c = $self->C;
    if ($c->project->features->{session} && $session && $session->{'sid'}) {
	$self->delete_session($session->{'sid'});
    }

    my $templatevars = $self->TemplateVars;
    $templatevars->{olduser} = param("olduser");
    $self->_tpl("bestwe", "we_logout_screen.tpl.html");
}

sub mainpanel {
    my $self = shift;
    if (!$self->HeaderPrinted) { print $self->myheader() }
    $self->identify;
    my $root = $self->Root;
    my $templatevars = $self->TemplateVars;
    $templatevars->{is_admin} = $root->is_allowed(["admin","useradmin","release","publish"]);
    $self->_tpl("bestwe", "we_mainpanel.tpl.html");
}

######################################################################
#
# show a we template
#
sub passthrough {
    my $self = shift;
    my %args;
    my $template = param('template');
    my($content_type) = $self->get_we_template_contenttype($template);
    if ($content_type ne "text/html") {
	$args{"-Content-Type"} = $content_type;
    }
    if (!$self->HeaderPrinted) { print $self->myheader(%args) }
    die "No '..' allowed in template specification!"
	if $template =~ m"(/|^)\.\.(/|$)";
    $self->_tpl("bestwe", $template);
} #### sub passthrough END

######################################################################
#
# show a project (site) template
#
sub passthroughsite {
    my $self = shift;
    my %args;
    my $template = param('template');
    my($content_type) = $self->get_we_template_contenttype($template);
    if ($content_type ne "text/html") {
	$args{"-Content-Type"} = $content_type;
    }
    if (!$self->HeaderPrinted) { print $self->myheader(%args) }
    die "No '..' allowed in template specification!"
	if $template =~ m"(/|^)\.\.(/|$)";
    $self->_tpl("site_we", $template);
} #### sub passthrough END

######################################################################
#
# preview a page
#
sub preview {
    my $self = shift;

    require Template;
    my $t = Template->new($self->TemplateConf);
    my $outdata;
    my $pagetype;
    if (!defined param("data") && defined param("pageid")) {
	my $pageid = param("pageid");
	my $root = $self->Root;
	my $objdb = $root->ObjDB;
	my $content = $objdb->content($pageid);
	$outdata = $self->_get_outdata($content);
	$pagetype = $outdata->{"data"}{"pagetype"};
    } else {
	$outdata = $self->_get_outdata();
	$pagetype = param("pagetype");
    }
    if (!$pagetype) {
	die "`pagetype' parameter is missing";
    }
    my $c = $self->C;
    my $template = $c->project->templatefortype->{$pagetype}
	or die "No template for page type `$pagetype'";

    my($content_type, $ext) = $self->get_template_contenttype($template);
    if (!$self->HeaderPrinted) {
	print $self->myheader(-type => $content_type);
    } else {
	warn "Header should not be already printed before preview()!";
    }

    my $out = "";

    if ($content_type eq 'text/html') {
	# fake a reasonable base, so internal links work to released pages
	my $absrooturl = $c->paths->absoluteurl;
	if ($absrooturl eq '') {
	    $absrooturl = $c->paths->rooturl;
	    if ($absrooturl !~ m|^https?://|) {
		$absrooturl = "http://" . server_name() . ":" . server_port() . $absrooturl;
	    }
	}
	my $ext = $c->project->standardext;
	# XXX This is not xhtml compliant!
	print '<base href="' . $absrooturl . '/html/' . $outdata->{'data'}->{'language'} . '/index' . $ext . '">' . "\n";
    }

    if (open(DEBUG3, ">/tmp/debug_dd_$<.txt")) {
	require Data::Dumper;
	print DEBUG3 Data::Dumper->new([$outdata],[])->Indent(1)->Useqq(1)->Dump;
	close DEBUG3;
    }

    my $template_file = $c->paths->site_templatebase."/".$template;
    $t->process($template_file,
		{ %{ $self->TemplateVars },
		  objid => $outdata->{'data'}->{'pageid'},
		  lang => $outdata->{'data'}->{'language'},
		  %$outdata },
		\$out)
	or die "Template process for file <$template_file> failed: "
	    . $t->error . ", \@INC is @INC, pid is $$, Template dump: "
		. $t->context->_dump;

    if ($c->project->features->{validate} &&
	$c->project->features->{validate} eq $content_type) {
	$self->validate_page($out, contenttype => $content_type);

    }

    ## Use the converter if necessary
    my $converter;
    if (1) {
	$converter = $self->get_string_charset_converter;
	print STDOUT $converter->($out);

	## Charset debugging
	if (0) {
	    if (open(DEBUG, ">/tmp/debug_converted_$<.html")) {
		print DEBUG $converter->($out);
		close DEBUG;
	    }

	    if (open(DEBUG2, ">/tmp/debug_raw_$<.html")) {
		print DEBUG2 $out;
		close DEBUG2;
	    }
	}
    }

    ## The version which does not care about conversion:
    if (0) {
	print $out;
    }

    if ($content_type eq 'text/html') {
	print <<'EOF',
<script><!--
    var has_focus = typeof( window.focus ) == "function" || navigator.appName == "Netscape";
    if (has_focus) window.focus();
// --></script>
EOF
    }

} #### sub preview END

######################################################################
#
# save a page
#
sub savepage {
    my $self = shift;
    $self->check_login;
    my $script_dumper = $self->ScriptDumper;
    eval "require $script_dumper"; die "Can't load script dumper: $@" if $@;
    my $outdata  = $self->_get_outdata(undef, $script_dumper);
    my $data     = $outdata->{data};
    my $pid      = $data->{pageid};
    my $title    = new WE::Util::LangString;
    my $keywords = new WE::Util::LangString;
    my $pagetype = $data->{pagetype};
    my $name     = $data->{name};

    # check if Name is unique
    my $uniquename = 1;
    my $name_message;
    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $templatevars = $self->TemplateVars;
    my $newobj = $objdb->get_object($pid);
    if (!defined $newobj->Name || $newobj->Name ne $name) {
	$name_message = $self->_ambiguous_name_message($name, $newobj);
	if (defined $name_message) {
	    $uniquename = 0;
	    $data->{name} = undef;
	}
    }

    my $pagevisible = $data->{visible};
    my $nodel       = $data->{nodel} ? "nodel" : "";
    my $inactive    = !!$data->{inactive};
    my $timeopen    = $data->{timeopen};
    my $timeexpire  = $data->{timeexpire};
    my $wwwauth     = $data->{wwwauth} || "";
    my $c = $self->C;
    foreach my $l (@{ $c->project->sitelanguages }) {
	next if (!$data->{$l}->{'title'});
	set_langstring($title, "$l", $data->{$l}->{'title'});
	set_langstring($keywords, "$l", $data->{$l}->{'keywords'});
    }
    $objdb->replace_content($pid, $self->_dump_outdata($outdata));

    my $set_attributes = sub {
	my($obj, $release_state) = @_;
	$obj->Release_State     ($release_state);
	$obj->Title             ($title);
	$obj->Keywords          ($keywords);
	$obj->{VisibleToMenu} = $pagevisible;
	$obj->Rights            ($nodel);
	if (!defined $wwwauth || $wwwauth eq "") {
	    delete $obj->{WWWAuth};
	} else {
	    $obj->{WWWAuth} = $wwwauth;
	}
	if ($self->has_timebasedpublishing) {
	    $obj->TimeOpen  ($timeopen);
	    $obj->TimeExpire($timeexpire);
	}
	if ($uniquename) {
	    $obj->Name($name);
	}
	$objdb->replace_object($obj);
    };

    my $notify_msg;
    if (param('release') eq "yes" && !$inactive) {

	my $versionedobj;

	my $set_released_attributes = sub {
	    my $obj = shift;
	    $set_attributes->($obj, "released");
	};

	# check in and release that version
	if (!$c->project->useversioning) {
	    $objdb->trim_old_versions($pid, -all => 1);
	}
	$versionedobj = $objdb->ci($pid);
	$set_released_attributes->($versionedobj);

	# set attributes for "main" object version
	$set_released_attributes->($newobj);

	# create a html-page
#XXX only if TimeOpen/TimeExpire applies, otherwise fire at daemon and deletepage
	$self->makehtmlpage($newobj->Id);
#XXX ditto
	# recreate the menu
	$self->makemenu if $self->can("makemenu");
	$self->update_auth_files if $self->can("update_auth_files");

#XXX use hooks?	WebEditor::OldFeatures::TimeBased::Hooks::page_released($self, $newobj->Id) if 

	if ($versionedobj && $c->project->sessionlocking) {
	    $objdb->unlock($versionedobj);
	}
#XXX if TimeOpen/TimeExpire applies, send another action identifier
	$notify_msg = $self->we_notify("release", { Id => $newobj->Id });
    } else {
	$set_attributes->($newobj,
			  $inactive ? "inactive" : "modified",
			 );
	if ($inactive) {
	    $self->deletehtmlpage($newobj->Id);
	}
    }

    if (param('release') eq "yes") {
	if ($inactive) {
	    $templatevars->{'message'} = $self->fmt_msg("msg_inactive_page_released", langstring($title));
	} else {
	    $templatevars->{'message'} = $self->fmt_msg("msg_active_page_released", langstring($title));
	}
    } else {
	$templatevars->{'message'} = $self->fmt_msg("msg_page_saved", langstring($title));
    }
    $templatevars->{'message'} = "\n$notify_msg" if $notify_msg;

    if (!$uniquename) {
	if ($c->project->sessionlocking) {
	    $objdb->unlock($newobj);
	}
	return $self->pageeditorframe
	    (-currentaction => "savepage",
	     -message => $name_message,
	     -pageid => $newobj->Id);
    }
#XXXdel:
#    $newobj->Name($name);
#    $objdb->replace_object($newobj);

    if ($c->project->sessionlocking) {
    	$objdb->unlock($newobj);
    }
    $templatevars->{'new'} = 1;
    $templatevars->{'parid'} = ($objdb->parent_ids($newobj->Id))[0];
    $self->_tpl("bestwe","we_ready_to_folder.tpl.html");
} #### sub savepage END

sub unlock {
    my $self = shift;
    my($pageid, $redirect) = @_;
    if (!defined $pageid) {
	$pageid = param("pageid");
    }
    if (defined $pageid) {
	my $c = $self->C;
	my $root = $self->Root;
	my $objdb = $root->ObjDB;
	if ($c->project->sessionlocking) {
	    $self->check_login;
	    my $obj = $objdb->get_object($pageid);
	    if ($obj) {
		$objdb->unlock($obj);
	    }
	}
    }
    if (defined $redirect) {
	$self->html_redirect($redirect);
    }
}

sub html_redirect {
    my $self = shift;
    my $url = shift;
    print <<EOF;
<html><head><meta http-equiv="refresh" content="0; URL=$url"></head></html>
EOF
    exit;
}

######################################################################
#
# create a page
#
sub createpage {
    my $self = shift;
    local $^W = 0; # because of Rights =~ ...

    my $root = $self->Root;
    $self->check_login;
    my $parid = param('pageid');
    my $objdb = $root->ObjDB;
    my $parent = $objdb->get_object($parid);
    my $fe = $self->FE;
    my $c = $self->C;
    my $rights = $parent->Rights;
    $rights = "" if !defined $rights;
    if (($rights !~ /nopage/ && $root->is_allowed("new-doc")) || $root->is_allowed("everything")) {
	# choose a data-prototype according to the pagetype
	my $pagetype = $self->_get_pagetype;
	# XXX wird das hier jemals getriggert???
 	if ($fe->can("Uploadpagetypes") &&
 	    $fe->Uploadpagetypes &&
 	    $fe->Uploadpagetypes->{$pagetype}) {
 	    $self->uploadpage($parid, $pagetype);
 	}

	# get empty data from file
	use vars qw($emptydata);
	undef $emptydata;
	do $c->paths->prototypedir."/empty_".$pagetype.".bin"
	    or die "No prototype data for pagetype $pagetype";
	my $outdata = {'data' => {
				  'pagetype' => $pagetype,
				  'pageid' => 'x',
				 }
		      };
	# XXX add hook for additional outdata
	# XXX move this also to hook???
#XXX	$outdata->{data}->{section} = $root->get_section($parid);

	my $title = new WE::Util::LangString;
	foreach my $l (@{ $c->project->sitelanguages }) {
	    # emptydata is from safe source (hopefully)
	    $ { $outdata->{data} }{$l} = eval $emptydata;
	    $title->{$l} = $outdata->{data}->{$l}->{'title'};
	}
	my $newobj = $objdb->insert_doc
	    (-content       => $self->_dump_outdata($outdata),
	     -contentType   => "application/x-perl",
	     -parent        => $parid,
	     -Type          => $pagetype,
	     -VisibleToMenu => 1,
	     -Title         => $title,
	    ) or die "Could not create page";
	warn "Created page id=" . $newobj->Id . "\n" if $c->debug;
	param('pageid' => $newobj->Id);
	$self->pageeditorframe(-currentaction => "createpage");
    } else {
	warn "Could not create page because of permissions";
	$self->siteeditorframe("Could not create page");
    }
} #### sub createpage END

######################################################################
#
# upload a HTML page
#
sub uploadpage {
    my $self = shift;
    my($parid, $pagetype) = @_;
    my $c = $self->C;
    my $objdb = $self->Root->ObjDB;
    warn "parid=$parid, pagetype=$pagetype" if $c->debug;

    if (param('uploadfile'.$c->project->sitelanguages->[0])) {
	$parid = param('parentid');
	$pagetype = param("pagetype") || "static";
	my $title = new WE::Util::LangString;
	my $outdata = { data => {} };
	$outdata->{data}->{pagetype} = $pagetype;
	foreach my $lang (@{ $c->project->sitelanguages }) {
	    $outdata->{"data"}->{$lang}->{"ct"} = "";
	    my $infile = param('uploadfile'.$lang);
	    warn "Upload lang=" . param('uploadfile'.$lang) . ", file=$infile"
		if $c->debug;
	    while (<$infile>) {
		$_ =~ s/\n//g;
		$_ =~ s/\r//g;
		$outdata->{"data"}->{$lang}->{'ct'} .= $_;
	    }
	    $outdata->{"data"}->{$lang}->{'title'} = param('title'.$lang);
	    $title->{$lang} = param('title'.$lang);
	}

	my $newobj = $objdb->insert_doc
	    (-content       => $self->_dump_outdata($outdata),
	     -contentType   => "application/x-perl",
	     -parent        => $parid,
	     -Type          => $pagetype,
	     -VisibleToMenu => 1,
	     -Title         => $title) or die "Could not create page";
	warn "Created page " . $newobj->Id if $c->debug;
	param('pageid' => $newobj->Id);
	$self->pageeditorframe(-currentaction => "uploadpage");
    } else {
	my $templatevars = $self->TemplateVars;
	$templatevars->{'sitelanguages'} = $c->project->sitelanguages;
	$templatevars->{'parid'} = $parid;
	$templatevars->{'pagetype'} = $pagetype;
	$self->_tpl("bestwe", "we_upload.tpl.html");
    }
    exit;
}

######################################################################
#
# create a folder
#
sub createfolder {
    my $self = shift;
    my $root = $self->Root;
    $self->check_login;
    my $c = $self->C;
    my $objdb = $root->ObjDB;
    my $parid = param('pageid');
    my $parent = $objdb->get_object($parid);
    warn "Folder $parid: allowed everything: " . $root->is_allowed("everything") .
	", new-folder: " . $root->is_allowed("new-folder") . "\n"
	    if $c->debug;
    my $rights = $parent->Rights;
    $rights = "" if !defined $rights;
    if (($rights !~ /nofolder/ && $root->is_allowed("new-folder")) || $root->is_allowed("everything")) {
	my $pagetype = "Folder";
	my $title = new WE::Util::LangString();
	foreach my $l (@{ $c->project->sitelanguages }) {
	    $title->{$l} = 'new folder';
	}
	$objdb->insert_folder(-parent        => $parid,
			      -Release_State => "released",
			      -IndexDoc      => undef,
			      -VisibleToMenu => 1,
			      -Title         => $title);
	$self->siteeditorframe("New folder created");
    } else {
	$self->siteeditorframe("No folder created (permission denied)");
    }
} #### sub createfolder END

######################################################################
#
# Update all released html pages (i.e. after template changes). This
# is also used for creating a site for time based publishing.
# Arguments: -pubhtmldir, -time, -logfh
sub updatehtml {
    my($self, %args) = @_;
    $self->identify;
    my $root = $self->Root;
    if (!$root->is_allowed(["admin","release"])) {
	die "This function is only allowed for users with admin or release rights\n";
    }

    my $c = $self->C;
    my $pubhtmldir = $args{-pubhtmldir} || $c->paths->pubhtmldir;
    my $now = $args{-now}; # XXX use for modified ObjDB
    my $logfh = $args{-logfh} || \*STDOUT;

    # This seems to safe some 60% of time:
    my $objdb = $root->ObjDB;
    $objdb = $objdb->cached_db;
    # XXX require WE::DB::ObjUtils;$objdb->current_database_view;#XXX some day maybe...

    require Template;
    my $templatevars = $self->TemplateVars;
    $templatevars->{'objdb'} = $objdb; # override with cached version
    $templatevars->{'localconfig'}{'now'} = $now;
    my $t = Template->new($self->TemplateConf);
    print $logfh <<EOF;
<html>
<head>
 <link rel="stylesheet" type="text/css" href="@{[ $c->paths->we_htmlurl ]}/styles/cms.css" />
</head>
<body>
EOF
    my $begin_time = time;
    print $logfh "<h1>" . _html($self->msg("msg_update_html_pages")) . " (" . _html($self->msg("cap_prelive")) . ")" . "</h1>\n";
    print $logfh "<h2>" . _html($self->msg("msg_create_html_pages")) . "</h2>\n";
    my $root_object = $objdb->root_object;
    my @seen_ids = $self->update_children($root_object->Id,
					  $t,
					  -objdb      => $objdb,
					  -indent     => 0,
					  -pubhtmldir => $pubhtmldir,
					  -logfh      => $logfh,
					  -now        => $now,
					 );

    my $root_id;
    if (defined $root_object->IndexDoc) {
	$root_id = $root_object->IndexDoc;
    } else {
	$root_id = $root_object->Version_Parent || $root_object->Id;
    }
    push @seen_ids, $root_id;

    print $logfh "<h2>" . _html($self->msg("msg_create_homepage_link")) . "</h2>\n";
    foreach my $lang (@{ $c->project->sitelanguages }) {
	my $langdir  = "$pubhtmldir/html/$lang";
	my $ext = $c->project->standardext;
	if (-e "$langdir/$root_id$ext") {
	    print $logfh (_html("($lang: index$ext => $root_id$ext) "));
	    unlink "$langdir/index$ext";
	    symlink("$root_id$ext", "$langdir/index$ext");
	}
    }

    $self->makefolderpage($root_object->Id,
			  $t,
			  -objdb      => $objdb,
			  -pubhtmldir => $pubhtmldir,
			  -logfh      => $logfh,
			  -now        => $now,
			 );
    print $logfh "<h2>" . _html($self->msg("msg_remove_old_symlinks")) . "</h2>\n";
    $self->cleanup_symlinks(-pubhtmldir => $pubhtmldir);
    print $logfh "<h2>" . _html($self->msg("msg_remove_old_pages")) . "</h2>\n";
    $self->cleanup_unreferenced_html(\@seen_ids, -pubhtmldir => $pubhtmldir);
    print $logfh "<br />\n";

    my $duration = time - $begin_time;
    printf $logfh "<h2>" . _html($self->msg("msg_ready")) . " (%02d min %02d sec)</h2>", $duration/60, $duration%60;

    print $logfh "<hr /><div class='admin'>";
    $self->_tpl("bestwe", "we_admin_body.tpl.html", undef, $logfh);
    print $logfh "</div></body></html>";
}

sub cleanup_symlinks {
    my($self, %args) = @_;
    require File::Find;
    # peacify -w
    local $File::Find::prune = $File::Find::prune;
    local $File::Find::dir   = $File::Find::dir;
    my $c = $self->C;
    my $pubhtmldir = $args{-pubhtmldir} || $c->paths->pubhtmldir;
    File::Find::find(sub {
	if (/^(\.svn|CVS|RCS)$/) {
	    $File::Find::prune = 1;
	    return;
	}
	if (-l $_) {
	    my $f = readlink($_);
	    return if (-e $f);
	    require File::Spec;
	    $f = File::Spec->rel2abs($f, $File::Find::dir);
	    return if (-e $f);
	    unlink $_;
	}
    }, $pubhtmldir . "/html");
}

sub cleanup_unreferenced_html {
    my($self, $seen_ids_ref, %args) = @_;
    my %seen_ids = map { defined $_ ? ($_=>1) : () } @$seen_ids_ref;
    my $c = $self->C;
    my $pubhtmldir = $args{-pubhtmldir} || $c->paths->pubhtmldir;
    my $logfh = $args{-logfh} || \*STDOUT;
    my $basedir = $pubhtmldir;
    my $ext = quotemeta $c->project->standardext;
    my $rx = qr/^(\d+)$ext$/;
    foreach my $lang (@{ $c->project->sitelanguages }) {
	my $langdir  = $basedir."/html/".$lang;
	if (opendir(D, $langdir)) {
	    while(defined(my $f = readdir(D))) {
		my $lf = "$langdir/$f";
		next if !-f $lf || -l $lf;
		if ($f !~ $rx) {
		    warn "Datei $lf wird ignoriert...\n";
		    next;
		}
		my $id = $1;
		if (!$seen_ids{$1}) {
		    print $logfh (_html($self->fmt_msg("msg_delete", $f)) . "<br />\n");
		    unlink $lf;
		}
	    }
	    closedir D;
	}
    }
}

sub update_children {
    my($self, $objid, $t, %args) = @_;
    my $root	   = $self->Root;
    my $objdb	   = $args{-objdb} || $root->ObjDB;
    my $c	   = $self->C;
    my $indent	   = $args{-indent};
    my $pubhtmldir = $args{-pubhtmldir} || $c->paths->pubhtmldir;
    my $logfh	   = $args{-logfh} || \*STDOUT;
    my $now        = $args{-now};
    my @seen_ids;
    my @children = $objdb->get_released_children($objid, -now => $now);
    foreach my $child (@children) {
        if ($child->is_folder) {
	    if ($child->{VisibleToMenu}) {
		print $logfh "&nbsp;"x$indent if $indent;
		print $logfh (_html($self->msg("cap_folder"))) . " \"" . _html(langstring($child->Title, $self->EditorLang)) . "\" (Id=" . $child->Id . ")<br>\n";
	    }
	    if ($child->{VisibleToMenu}) {
		push @seen_ids, $self->makefolderpage
		    ($child->Id,
		     $t,
		     -pubhtmldir => $pubhtmldir,
		     -objdb	 => $objdb,
		     -logfh	 => $logfh,
		     -now        => $now,
		    );
	    }
	    push @seen_ids, $self->update_children
		($child->Id,
		 $t,
		 -objdb => $objdb,
		 (defined $indent ? (-indent => $indent+1) : ()),
		 -now => $now,
		);
	} else {
	    #next if !$child->{VisibleToMenu};
	    print $logfh "&nbsp;"x$indent if $indent;
	    print $logfh (_html($self->msg("cap_page"))) . " \"" . _html(langstring($child->Title, $self->EditorLang)) . "\" (Id=" . $child->Id . "): ";
	    my($msg_html, $seen_ids_ref) = $self->makehtmlpage
		($child->Id,
		 -tmplobj    => $t,
		 -objdb      => $objdb,
		 -pubhtmldir => $pubhtmldir,
		);
	    print $logfh $msg_html;
	    push @seen_ids, @$seen_ids_ref;
	    print $logfh "\n";
	}
    }
    @seen_ids;
}

# create an empty folder page if there is no IndexDoc
sub makefolderpage {
    my($self, $id, $t, %args) = @_;
    my $root = $self->Root;
    my $basedir = $args{-pubhtmldir} || die "-pubhtmldir not specified";
    my $objdb   = $args{-objdb} || $root->ObjDB;
    my $logfh   = $args{-logfh} || \*STDOUT;
    my $now     = $args{-now};

    my $obj = $objdb->get_object($id);
    return () if !$obj->{VisibleToMenu};
    my $mainid = $obj->Version_Parent;
    $mainid = $id if !defined $mainid;
    my $docid = $obj->IndexDoc;

    my @ret = ($docid);
    my $active = $objdb->is_active_page($obj);
    if (!$active) {
	@ret = ();
	print $logfh (_html(" - nicht erzeugen")); # XXX langres!
    }

    my $converter = $self->get_fh_charset_converter;

    my $c = $self->C;
    foreach my $lang (@{ $c->project->sitelanguages }) {
	my $langdir  = $basedir."/html/".$lang;
	my $ext = $c->project->standardext;
	if (!-d $langdir) {
	    mkdir $langdir, 0755 or die "Can't create $langdir: $!";
	}
	if (!defined $docid) {
	    # XXX code doubled in WE_Frontend::Plugin::WE_Navigation::Object
	    my $autoindexdoc = $c->project->features->{autoindexdoc};
	    if (defined $autoindexdoc && $autoindexdoc eq 'first') {
		my(@children_ids) = $objdb->get_released_children($mainid, -now => $now);
		if (@children_ids) {
		    $docid = $children_ids[0]->Id;
		}
	    }
	}
	if (!defined $docid) {
	    $docid = $mainid;
	    # process Template
	    my $outdata = {};
	    $outdata->{'data'}->{'language'} = $lang;
	    my $pagetype = "folderindex";
	    my $template = $c->project->templatefortype->{$pagetype}
		or die "Can't get template for $pagetype";
	    (undef, $ext) = $self->get_template_contenttype($template);
	    my $htmlfile = $langdir."/".$mainid.$ext;
	    if (!$active) {
		unlink $htmlfile;
	    } else {
		my $tmpfile  = "$htmlfile~";
		open HTML, ">$tmpfile" or die "Publish: can't write to $tmpfile: $!";
		$converter->(\*HTML);

		$outdata->{'data'}->{'pagetype'} = $pagetype;
		my $keywords = langstring($obj->{Keywords}, $lang) || undef;
		my $t = Template->new($self->TemplateConf);
		$t->process($c->paths->site_templatebase."/".$template,
			    { %{$self->TemplateVars},
			      objid => $mainid,
			      lang => $lang,
			      keywords => $keywords,
			      %$outdata }, \*HTML)
		    or die "Template process failed: " . $t->error . "\n";
		close HTML;

		require File::Compare;
		if (File::Compare::compare($htmlfile, $tmpfile) == 0) {
		    # no change --- delete $tmpfile
		    unlink $tmpfile;
		} else {
		    unlink $htmlfile; # do not fail --- maybe file does not exist
		    rename $tmpfile, $htmlfile or die "Can't rename $tmpfile to $htmlfile: $!";
		}
	    }
	}

	if (eval { symlink("",""); 1 }) { # symlink exists
	    if ($mainid != $docid) {
		my $oldfile  = $docid.$ext;
		my $linkfile = $langdir."/".$mainid.$ext;
		local $^W = undef;
		if (readlink($linkfile) ne $oldfile) {
		    unlink $linkfile;
		    if ($active) {
			symlink $oldfile, $linkfile
			    or warn "Can't symllink $docid => $mainid";
			print $logfh (_html(" ($lang: " . $self->fmt_msg("msg_link_to", $oldfile) . ") "));
		    }
		} else {
		    print $logfh (_html(" ($lang: " . $self->msg("msg_no_change") . ") "));
		}
		push @ret, $mainid;
	    }
	    for my $name ($root->NameDB->get_names($docid)) {
		my $oldfile  = $docid.$ext;
		my $linkfile = $langdir."/".$name.$ext;
		local $^W = undef;
		if (readlink($linkfile) ne $oldfile) {
		    unlink $linkfile;
		    if ($active) {
			symlink $oldfile, $linkfile
			    or warn "Can't symllink $name => $docid";
			print $logfh (_html(" ($lang: " . $self->fmt_msg("msg_link_to", $oldfile) . ") "));
		    }
		} else {
		    print $logfh (_html(" ($lang: " . $self->msg("msg_no_change") . ") "));
		}
	    }
	}
    }
    print $logfh "<br>\n";

    return @ret;
}

sub makehtmlpage {
    my($self, $id, %args) = @_;
    my $c = $self->C;
    my $root = $self->Root;
    my $basedir = $args{-pubhtmldir} || $c->paths->pubhtmldir;
    my $t       = $args{-tmplobj} || do {
	require Template;
	Template->new($self->TemplateConf);
    };
    my $objdb   = $args{-objdb}   || $root->ObjDB;

    my $msg = ""; # as HTML
    my $content = $objdb->content($id);
    my $outdata = $self->_get_outdata($content);
    my $obj = $objdb->get_object($id);
    my $mainid = $obj->Version_Parent || $id;
    my $template = $c->project->templatefortype->{ $outdata->{'data'}->{'pagetype'} };
    if (!defined $template) {
	die "No template for pagetype $outdata->{'data'}->{'pagetype'} defined";
    }

    require File::Compare;
    my($ext) = $template =~ /(\.[^\.]+)$/;

    my $converter = $self->get_fh_charset_converter;

    foreach my $lang (@{ $c->project->sitelanguages }) {
	my $langdir  = $basedir."/html/".$lang;
	if (!-d $langdir) {
	    mkdir $langdir, 0755 or die "Can't create $langdir: $!";
	}
	my $htmlfile = $langdir."/".$mainid.$ext;
	my $tmpfile  = "$htmlfile~";
	open HTML, ">$tmpfile" or die "Publish: can't write to $tmpfile: $!";
	$converter->(\*HTML);
	
	# process Template
	$outdata->{'data'}->{'language'} = $lang;
	my $keywords = langstring($obj->{Keywords}, $lang) || undef;
	#warn "Using template ".$c->paths->site_templatebase."/".$template."\n";
	$t->process($c->paths->site_templatebase."/".$template,
		    { %{ $self->TemplateVars },
		      objid => $mainid,
		      lang => $lang,
		      keywords => $keywords,
		      %$outdata }, \*HTML)
	    or die "Template process failed: " . $t->error . "\n";
	close HTML;

	if (File::Compare::compare($htmlfile, $tmpfile) == 0) {
	    # no change --- delete $tmpfile
	    unlink $tmpfile;
	    $msg .= _html(" ($lang: " . $self->msg("msg_no_change") . ") ");
	} else {
	    unlink $htmlfile; # do not fail --- maybe file does not exist
	    rename $tmpfile, $htmlfile or die "Can't rename $tmpfile to $htmlfile: $!";
	    $msg .= _html(" ($lang: $htmlfile) ");
	}

	if (eval { symlink("",""); 1 }) { # symlink exists
	    for my $name ($root->NameDB->get_names($mainid)) {
		unlink $langdir."/".$name.$ext;
		symlink $mainid.$ext, $langdir."/".$name.$ext;
	    }
	}

	my @makehtmlhooks;
	my $makehtmlhook = $c->project->features->{makehtmlhook};
	if ($makehtmlhook) {
	    if (UNIVERSAL::isa($makehtmlhook, "ARRAY")) {
		push @makehtmlhooks, @{ $makehtmlhook };
	    } else {
		push @makehtmlhooks, $makehtmlhook;
	    }
	}
	# legacy mixin'ed method:
	push @makehtmlhooks, "additional"
	    if $self->can("makehtmlpage_additional");

	my @add_msg;
	for my $hook (@makehtmlhooks) {
	    my $method = "makehtmlpage_" . $hook;
	    my $ret = $self->$method
		(id              => $id,
		 mainid          => $mainid,
		 lang            => $lang,
		 basedir         => $basedir,
		 template        => $template,
		 addtemplatevars => { objid => $mainid,
				      lang  => $lang,
				      %$outdata
				    });
	    if (UNIVERSAL::isa($ret, "HASH")) {
		# modern return type
		push @add_msg, $ret->{Message};
	    } else {
		# legacy return type
		push @add_msg, $ret;
	    }
	}
	my $add_msg = join "", @add_msg;
	$msg .= " - $add_msg" if defined $add_msg && $add_msg ne ""; # XXX htmlify?
    }

    ($msg . "<br>\n", [$mainid]);
}

sub deletehtmlpage {
    my $self = shift;
    my($id) = @_;
    my $c = $self->C;
    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $basedir = $c->paths->pubhtmldir;
    my $obj = $objdb->get_object($id);
    my $mainid = $obj->Version_Parent || $id;
    my $ext = $c->project->standardext;

    foreach my $lang (@{ $c->project->sitelanguages }) {
	my $langdir  = $basedir."/html/".$lang;
	next if (!-d $langdir);
	my $htmlfile = $langdir."/".$mainid.$ext;
	unlink $htmlfile;

	if (eval { symlink("",""); 1 }) { # symlink exists
	    for my $name ($root->NameDB->get_names($mainid)) {
		unlink $langdir."/".$name.$ext;
	    }
	}
    }
}

######################################################################
#
# edit a folder
#
sub folderedit {
    my $self = shift;

    local $^W = 0; # because of Rights =~ ...

    $self->check_login;

    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $c = $self->C;

    my $folderid = param('pageid');
    my $fldr = $objdb->get_object($folderid);
    if (!$fldr) {
	# Folder probably deleted => show blank page
	# XXX or probably a plain message/error page?
	exit(0);
    }

    if (!$root->is_allowed(["edit", "edit-only"], $folderid)) {
	$self->siteeditorframe("No permission to edit folder $folderid");
	return;
    }

    # Save folder
 TRY_SAVE_FOLDER: {
	if (param('action') eq "save") {
	    my $converter = $self->get_string_charset_decode_converter;
	    my $title = new WE::Util::LangString;
	    foreach my $l (@{ $c->project->sitelanguages }) {
		$title->{$l} = $converter->(param("newtitle$l"));
	    }
	    $fldr->Title($title);
	    my $idxp = param('indexpage') || undef;
	    $fldr->IndexDoc($idxp);
	    my $foldername = param('foldername') || 0;
	    if ($foldername) {
		# check if Name is unique
		if ($fldr->Name ne $foldername) {
		    my $name_message = $self->_ambiguous_name_message($foldername, $fldr);
		    if (defined $name_message) {
			param('message' => $name_message);
			param('action' => 'show');
			last TRY_SAVE_FOLDER;
		    }
		}
	    }
	    $fldr->Name($foldername);
	    my $foldergroup = param('group') || "none";
	    if ($foldergroup) { $fldr->{Group} = $foldergroup }
	    my $rights = join(",", param('nodel'), param('nopage'), param('nofolder'));
	    $fldr->Rights($rights);
	    if (param('inactive')) {
		$fldr->Release_State('inactive');
	    } elsif ($fldr->{Release_State} eq 'inactive') {
		$fldr->Release_State('released');
	    }
	    $fldr->{VisibleToMenu} = !param('hidden');

	    my $timeopen = param('timeopen') || "";
	    if ($timeopen) {
		$timeopen .= " " . param('timeopen_time');
	    }
	    my $timeexpire = param('timeexpire') || "";
	    if ($timeexpire) {
		$timeexpire .= " " . param('timeexpire_time');
	    }
	    $fldr->TimeOpen($timeopen);
	    $fldr->TimeExpire($timeexpire);

	    $objdb->replace_object($fldr);
	    param('fromid' => $folderid);
	    return $self->siteeditorframe();
	}
    }

    # Delete folder
    if (param('action') eq "delete") {
	if ($folderid == $objdb->root_object->Id) {
	    param('message' => $self->msg("msg_cant_del_root"));
	    param("action" => "show");
	} else {
	    if (($fldr->Rights !~ /nodel/ && $root->is_allowed("change-folder"))
		|| $root->is_allowed("everything")) {
		my $parid = ($objdb->parent_ids($folderid))[0];
		$objdb->remove($folderid);
		my $notify_msg = $self->we_notify("deletefolder", { Id => $folderid });
		param("pageid" => $parid);
		my $msg = $self->fmt_msg("msg_folder_del_id", $folderid);
		$msg .= "\n$notify_msg" if $notify_msg;
		param("message" => $msg);
	    }
	}
	return $self->siteeditorframe();
    }

    # Release folder
    if (param('action') eq 'release') {
	if (!$root->is_allowed("everything") &&
	    !$root->is_allowed("release", $folderid)) {
	    $self->siteeditorframe("No permission to release folder $folderid");
	    return;
	}

	my @objids;

	my $useversioning = $c->project->useversioning;

	my $release_sub = sub {
	    my $objid = shift;
	    my $obj = $objdb->get_object($objid);
	    if ($root->is_releasable_page($obj)) {
		$root->release_page($obj, -useversioning => $useversioning);
		push @objids, $objid;
	    }
	};
	# First release all ...
  	$objdb->walk_preorder($folderid, $release_sub);

	# ... then update html
	require Template;
	my $t = Template->new($self->TemplateConf);
	$self->update_children($folderid, $t);# XXX supply -now => $now?
	param("message" => $self->msg("msg_release_complete"));

	my $notify_msg;
	if (@objids) {
	    $notify_msg = $self->we_notify("release", { Id => \@objids });
	}

	return $self->siteeditorframe($notify_msg);

    # Publish folder
    } elsif (param('action') eq 'publish') {
	if (!$root->is_allowed("everything") &&
	    !$root->is_allowed("publish", $folderid)) {
	    $self->siteeditorframe($self->fmt_msg("msg_no_perm_folder_publish", $folderid));
	    return;
	}
	$self->folderpublish($folderid);

    # Show folder listing
    } elsif (param('action') eq "show") {
	# Show folder editor

	my $templatevars = $self->TemplateVars;
	# resolve Languagestring
	my $titlestr = $fldr->Title;
	my $title;
	my %mytitles;
	if (UNIVERSAL::isa($titlestr,'WE::Util::LangString')) {
	    foreach my $l (@{ $c->project->sitelanguages }) {
		$mytitles{$l} = $titlestr->get($l);
	    }
	} else {
	    $title = $titlestr;
	}
	my $name = $fldr->Name || "";
	my $movechildid = param('movechildid');
	if (defined $movechildid && $movechildid ne "") {
	    my $beforechildid = param('beforechildid');
	    if (defined $beforechildid && $beforechildid ne "") {
		$objdb->move($movechildid, $folderid,
			     -before => $beforechildid);
		warn "move $movechildid before $beforechildid\n"
		    if $c->debug;
	    }
	    my $belowchildid = param('belowchildid');
	    if (defined $belowchildid && $belowchildid ne "") {
		$objdb->move($movechildid, $folderid,
			     -after => $belowchildid);
		warn "move $movechildid below $belowchildid\n"
		    if $c->debug;
	    }
	    $templatevars->{'updatebutton'} = 1;
	}
	my $can_move_doc    = $root->is_allowed("move-doc");
	my $can_move_folder = $root->is_allowed("move-folder");
	my $can_copy_doc    = $root->is_allowed("copy-doc");
	my $can_copy_folder = $root->is_allowed("copy-folder");
	my @list;
	my @children = $objdb->children($folderid);
	my $last = -1;
	my $noindex = 1;
	foreach my $child (@children) {
	    my $ttl = langstring($child->Title, $self->EditorLang);
	    my $str = "<tr><td class=\"adminbg_grey\" align=center>";
	    if ($child->is_folder) {
		$str .= "&nbsp;</td>";
	    } else {
		my $c = defined $fldr->IndexDoc && $fldr->IndexDoc eq $child->Id ? " checked":"";
		$str .= "<input type=radio name=indexpage value='".$child->Id."' ".$c."></td>";
		if ($c eq " checked") { $noindex = 0 }
	    };
	    $str .= "<td>" . _html($ttl) . " </td><td>";
	    my $i1 = $child->Id;
	    if ($last >= 0) {
		my $i2 = $children[$last]->Id;
		$str .= "<a href='javascript:up($i1,$i2)'>" . _html($self->msg("cap_up")) . "</a>";
	    } else {
		my $i2 = $children[-1]->Id;
		$str .= "<a href='javascript:down($i1,$i2)'>" . _html($self->msg("cap_bottom")) . "</a>";
	    }
	    $str .= "</td><td>";
	    $last++;
	    if ($last < $#children) {
		my $i2 = $children[$last+1]->Id;
		$str .= "<a href='javascript:down($i1,$i2)'>" . _html($self->msg("cap_down")) . "</a>";
	    } else {
		my $i2 = $children[0]->Id;
		$str .= "<a href='javascript:up($i1,$i2)'>" . _html($self->msg("cap_top")) . "</a>";
	    }
	    $str .= "</td><td>";

	    if (   ($child->is_folder && $can_move_folder)
		|| ($child->is_doc    && $can_move_doc)) {
		$str .= "<a href='#' onclick='return top.site.copy_move(\"" . $c->paths->cgiurl . "/we_redisys.cgi\", \"move\", $i1, unescape(\""._uri_escape($ttl)."\"));' " . _js_status_str(_uri_escape($self->fmt_msg("cap_move_with_title", $ttl))) . ">" . _html($self->msg("cap_move")) . "</a>";
	    }
	    $str .= "</td><td>";
	    if (   ($child->is_folder && $can_copy_folder)
		|| ($child->is_doc    && $can_copy_doc)) {
		$str .= "<a href='#' onclick='return top.site.copy_move(\"" . $c->paths->cgiurl . "/we_redisys.cgi\", \"copy\", $i1, unescape(\""._uri_escape($ttl)."\"));' " . _js_status_str(_uri_escape($self->fmt_msg("cap_copy_with_title", $ttl))) . ">" . _html($self->msg("cap_copy")) . "</a>";
	    }
	    $str .= "</td></tr>\n";
	    push @list, $str;
	}
	$templatevars->{'foldername'}    = $name;
	$templatevars->{'noindex'}       = $noindex;
	$templatevars->{'list'}          = \@list;
	$templatevars->{'mytitles'}      = \%mytitles;
	$templatevars->{'sitelanguages'} = $c->project->sitelanguages;
	$templatevars->{'f_id'}          = $folderid;
	$templatevars->{'message'}       = param('message');
	require Data::JavaScript;
	$templatevars->{'datadump'}      = Data::JavaScript::jsdump('data', $fldr);
	# whether this folder may be deleted
	$templatevars->{'delbutton'} = 0;
	if ( $fldr->Rights !~ /nodel/ && $root->is_allowed("change-folder")) { $templatevars->{'delbutton'} = 1 }
	if ( $root->is_allowed("change-folder", $folderid)) { $templatevars->{'changeorder'} = 1 }
	if ( $can_move_folder || $can_move_doc ) { $templatevars->{'move'} = 1 }
	if ( $can_copy_folder || $can_move_folder ) { $templatevars->{'copy'} = 1 }
	if ( $fldr->Rights =~ /\bnodel\b/) { $templatevars->{'nodel'}="checked" }
	if ( $fldr->Rights =~ /\bnopage\b/) { $templatevars->{'nopage'}="checked" }
	if ( $fldr->Rights =~ /\bnofolder\b/) { $templatevars->{'nofolder'}="checked" }
	if ( $fldr->Release_State eq 'inactive') { $templatevars->{'inactive'}="checked";}
	if ( !$fldr->{VisibleToMenu}) { $templatevars->{'hidden'}="checked" }
	# whether user may release the folder
	$templatevars->{'releasebutton'} = 0; # deprec? XXX
	if ( $root->is_allowed("everything")) { $templatevars->{'delbutton'} = 1 }
	# whether user is admin
	if ( $root->is_allowed("everything")) { $templatevars->{'isadmin'} = 1 }
#XXX delete (?)
	if ( UNIVERSAL::isa($fldr, "WE::Obj::Site") )    {
	    $templatevars->{'issite'} = 1;
	}
	if ($root->is_allowed("everything") ||
	    $root->is_allowed("release", $folderid)) {
	    $templatevars->{'releasebutton'} = 1;
	}
	if ($c->staging &&
	    ($root->is_allowed("everything") ||
	     $root->is_allowed("publish", $folderid))
	   ) {
	    $templatevars->{'publishbutton'} = 1;
	}

	# group
	$templatevars->{'group'} = $objdb->get_object($folderid)->{Group} || "none";

	# process Template
	$self->_tpl("bestwe", "we_folderedit.tpl.html");
    } else {
	$self->siteeditorframe();
    }
} #### sub folderedit END

sub folderpublish {
    my($self, $folderid) = @_;
    # Access checks should be already done.

    # XXX only supported for rsync method
    require WE_Frontend::Publish::Rsync;

    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;
    my $ext   = $c->project->standardext;

    my @unlang_base_file_names;
    my $publish_sub = sub {
	my $objid = shift;
	if ($root->is_releasable_page($objid)) {
	    push @unlang_base_file_names, $objid;
	    push @unlang_base_file_names, $self->get_alias_pages($objid);
	}
    };
    $objdb->walk_preorder($folderid, $publish_sub);

    my @base_file_names;
    for my $base (@unlang_base_file_names) {
	for my $lang (@{ $c->project->sitelanguages }) {
	    push @base_file_names, "html/$lang/$base$ext";
	}
    }

    my $ret = WE_Frontend::Publish::Rsync::publish_files
	($self->FE, \@base_file_names, -n => 0, -verbose => 1);

    if ($ret) {
	if (@base_file_names) {
	    my $last = pop @base_file_names;
	    my $quote = sub { '»'.$_[0].'«' };
	    my $file_list = $quote->($last);
	    if (@base_file_names) {
		$file_list = join(", ", map { $quote->($_) } @base_file_names)
		    . " " . $self->msg("cap_and") . " " . $file_list;
	    }
	    param("message" => $self->fmt_msg("msg_html_published", $file_list));
	} else {
	    param("message" => $self->msg("msg_no_html_published"));
	}
    } else {
	param("message" => $self->msg("msg_html_publish_error"));
    }

    my $notify_msg = $self->we_notify("folderpublish", { Id => $folderid });

    return $self->siteeditorframe($notify_msg);
}

######################################################################
#
# delete a page
#
sub deletepage {
    my $self = shift;
    my $objid = param('pageid');
    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    if (!$objdb->exists($objid)) {
	die "The object with the id $objid does not exist and cannot be deleted.";
    }

    $self->identify;
    if (!$root->is_allowed(["edit", "delete-doc"], $objid)) { # but not edit-only
	die "Deletion of $objid not allowed for " . $self->User;
    }

    my $templatevars = $self->TemplateVars;
    $templatevars->{'parid'} = ($objdb->parent_ids($objid))[0];
    $objdb->remove($objid);

    my $notify_msg = $self->we_notify("deletepage", { Id => $objid });

    $templatevars->{'message'} = $self->fmt_msg("msg_page_deleted", $objid);
    $templatevars->{'message'} .= "\n$notify_msg" if $notify_msg;
    $templatevars->{'new'} = 1;
    $self->_tpl("bestwe", "we_ready_to_folder.tpl.html");
} #### sub deletepage END

sub cancelpage {
    my $self = shift;
    my $objid = param('pageid');
    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $c = $self->C;
    my $obj = $objdb->get_object($objid);
    if (!$obj) {
	die "Object with id $objid does not exist in database";
    }
    if ($c->project->sessionlocking) {
	$objdb->unlock($obj);
    }
    my $parentid = ($objdb->parent_ids($objid))[0];
    # XXX maybe make a template
    print <<EOF
<html><head></head><body><script><!--
top.site.action('$parentid','site','','view','','');
//--></script></body></html>
EOF
}

######################################################################
#
# main frame
#
sub mainframe {
    my $self = shift;
    $self->login($self->msg("msg_login_incorrect"))
	unless $self->identify;
    $self->_tpl("bestwe", "we_mainframe.tpl.html");
}

######################################################################
#
# content editor frame
#
sub pageeditorframe {
    my($self, %args) = @_;
    $self->_tpl("bestwe", "we_pageframeset.tpl.html",
		{
		 'pageid'        => defined $args{-pageid} ? $args{-pageid} : param('pageid'),
		 'currentaction' => $args{'-currentaction'},
		 'message'       => $args{'-message'},
		}
	       );
}

######################################################################
#
# content editor page
#
sub pageedit {
    my $self = shift;
    local $^W = 0; # because of Rights =~ ...

    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $c = $self->C;
    $self->check_login;

    my $pageid = param('pageid') || $_[0];
    unless ($root->is_allowed(["edit", "edit-only"], $pageid)) {
	my $obj = $objdb->get_object($pageid);
	$self->siteeditorframe($self->fmt_msg("msg_no_perm_page_edit", langstring($obj->Title) . " (Id $pageid)"));
	return;
    }

    my $pageobj = $objdb->get_object($pageid);
    my $datfile;

    if ($c->project->sessionlocking) {
	if ($objdb->is_locked($pageobj)) {
	    my $lock_msg = _uri_escape
		($self->fmt_msg("msg_page_locked",
				langstring($pageobj->Title, $self->EditorLang),
				$pageobj->LockedBy));
	    my $folderid = ($objdb->parent_ids($pageobj))[0];
	    print <<EOF;
<script>
alert(unescape("$lock_msg"));
location.href='@{[ $c->paths->cgiurl ]}/we_redisys.cgi?goto=siteeditorframe&pageid=$folderid';
</script>
EOF
            exit;
	}
	$objdb->lock($pageobj, -type => 'SessionLock');
    }

    my $outdata = eval { $self->_get_outdata($objdb->content($pageid)) };
    my $message = $@;
    $outdata->{'data'}->{'pageid'}  = $pageid;
    $outdata->{'data'}->{'visible'} = $pageobj->{'VisibleToMenu'};
    $outdata->{'data'}->{'nodel'}   = $pageobj->{'Rights'}=~"nodel" ? "1" : "0";
    $outdata->{'data'}->{'timeopen'}   = $pageobj->TimeOpen   || "";
    $outdata->{'data'}->{'timeexpire'} = $pageobj->TimeExpire || "";

    require Data::JavaScript;
    my @jscode = Data::JavaScript::jsdump('data', $outdata->{data});

    my $delbutton = $pageobj->Rights !~ /nodel/ || $root->is_allowed("everything") ? 1:0;
    my $releasebutton = $root->is_allowed("release", $pageid) ? 1:0;
    $self->_tpl("bestwe", "we_pagedata.tpl.html",
		{
		 'delbutton'     => $delbutton,
		 'releasebutton' => $releasebutton,
		 'jsarray'       => \@jscode,
		 'sitelanguages' => $c->project->sitelanguages,
		 'new'           => 1,
		 'message'       => $message,
		}
	       );
}

######################################################################
#
# show content-element editor
#
sub showeditor {
    my $self = shift;

    if (param("usetemplate")) {
	return $self->showeditor_template;
    }

    my $et = param('elementtype');
    my $c = $self->C;
    warn "showeditor elementtype=$et\n" if $c->debug;

    my $showeditor_methods = $self->showeditor_methods;
    while(my($key, $method) = each %$showeditor_methods) {
	if ($et =~ /^$key/) {
	    return $self->$method();
	}
    }
    print <<EOF;
<html><body bgcolor=#ffffff>
unhandled type $et
</body></html>
EOF
}

sub showeditor_any {
    my $self = shift;
    $self->identify;
    my $type = param("elementtype");
    my $root = $self->Root;
    my $c = $self->C;
    my $basedir = ($type =~ /^image/ ? $c->paths->photodir :
		   $type =~ /^download/ ? $c->paths->rootdir ."/download" :
		   die "Unhandled type $type");
    my @accept = ($type =~ /^image/ ? ("image/gif", "image/jpeg", "image/png") : ());

    my $action  = param("action");
    my $message = param("message");
    my $selectedfolder = param("selectedfolder");

    my $can_edit   = $root->is_allowed(["edit", "edit-only"]);
    my $can_upload = $can_edit || $root->is_allowed('new-image');
    my $can_newdir = $can_edit || $root->is_allowed('new-imagefolder');
    my $can_delete = $can_edit || $root->is_allowed('delete-image');
    my $can_rename = $can_edit || $root->is_allowed('rename-image');

    if (defined $action && $action ne "") {
	if (!$can_edit && !$can_upload && !$can_newdir && !$can_delete && !$can_rename) {
	    die "Edit not allowed for " . $self->User;
	}
	if ($action eq 'upload' && ($can_edit || $can_upload)) {
	    $message = $self->showeditor_any_upload
		($basedir,
		 -checkext => $type,
		);
	} elsif ($action eq 'newfolder' && ($can_edit || $can_newdir)) {
	    $message = $self->showeditor_any_newfolder
		($basedir
		);
	} elsif ($action eq 'delete' && ($can_edit || $can_delete)) {
	    $message = $self->showeditor_any_delete
		($basedir
		);
	} elsif ($action eq 'rename' && ($can_edit || $can_rename)) {
	    $message = $self->showeditor_any_rename
		($basedir,
		 -checkext => $type,
		);
	}
	# fall through...
    }

    my $handle_directory;
    $handle_directory = sub {
	my($dir) = @_;

	my %files;
	# for the correct sort order
	if (eval 'local $SIG{__DIE__}; require Tie::IxHash; 1') {
	    tie %files, 'Tie::IxHash';
	}

	local *DIR;
	opendir(DIR, $dir)
	    or $self->error("Can't open $dir: $!");
	while (defined(my $direntry = readdir(DIR))) {
	    next if $direntry=~/^\.|CVS|RCS|\.svn/i; # dont show hidden or special files
	    my $f = "$dir/$direntry";
	    if (-d $f) {
		my $subfiles = $handle_directory->($f);
		$files{$direntry} = $subfiles;
	    } else {
		$files{$direntry} = undef;
	    }
	}
	closedir DIR;

	if (tied %files && (tied %files)->can('SortByKey')) {
	    (tied %files)->SortByKey;
	}

	\%files;
    };

    my $files = $handle_directory->($basedir);

    require Data::JavaScript;
    my @filedata = Data::JavaScript::jsdump('filedata', $files);

    $self->_tpl("bestwe", "we_imagechooser.tpl.html",
		{
		 'elementtype'    => param('elementtype')||"",
		 'filedata'       => \@filedata,
		 'message'        => $message,
		 'selectedfolder' => $selectedfolder,
		 'accept'         => \@accept,
		 'no_edit'        => !$can_edit,
		 'can_upload'     => $can_upload,
		 'can_newdir'     => $can_newdir,
		 'can_delete'	  => $can_delete,
		 'can_rename'	  => $can_rename,
		}
	       );
}

sub showeditor_template {
    my $self = shift;
    my $elementtype = param("elementtype");
    if ($elementtype !~ /^[a-zA-Z0-9_.-]+$/) {
	die "Invalid characters in elementtype $elementtype (only characters, numbers, dot, dash and underline allowed";
    }
    require Safe;
    my $cpt = Safe->new;
    my $obj = $cpt->reval(CGI::unescape(param("obj")));
    my %addvars = (elementtype => $elementtype,
		   lang        => param("language")||"",
		   path        => param("path")||"",
		   obj         => $obj,
		  );
    $self->_tpl("bestwe", "editor_template_header.tpl.html",
		{ %{ $self->TemplateVars }, %addvars }
	       );
    $self->_tpl("bestwe", "editor_template_$elementtype.tpl.html",
		{ %{ $self->TemplateVars }, %addvars }
	       );
    $self->_tpl("bestwe", "editor_template_footer.tpl.html",
		{ %{ $self->TemplateVars }, %addvars }
	       );
}

######################################################################

sub showeditor_any_upload {
    my $self = shift;
    my($basedir, %args) = @_;
    my $filename = param("uploadname");
    my $folder = param("selectedfolder");
    my $e = $self->msg("msg_showeditor_upload_error") . ": ";
    if (!defined $filename || $filename eq '') {
	return $e . $self->msg("msg_showeditor_no_upload_file");
    }
    if ($folder =~ /^\s*$/) {
	return $e . $self->msg("msg_showeditor_missing_upload_dir");
    }
    if (_invalid_file_name($folder) || $folder =~ /^\./) {
	return $e . $self->fmt_msg("msg_showeditor_invalid_dirname", $folder);
    }
    my $abs_folder = $basedir . "/" . $folder;
    if (!-e $abs_folder) {
	return $e . $self->fmt_msg("msg_showeditor_no_upload_dir", $abs_folder);
    }
    my $sane_filename = _sane_file_name(_universal_basename($filename));
    if ($args{'-checkext'} eq 'image') {
	if (!$self->_check_allowed_image_extensions($sane_filename)) {
	    return $e . $self->fmt_msg("msg_showeditor_invalid_ext",
				       join(", ", $self->_allowed_image_extensions()),
				       $sane_filename
				      );
	}
    }
    my $dest_filename = "$abs_folder/$sane_filename";
    if (-e $dest_filename) {
	return $e . $self->fmt_msg("msg_showeditor_filename_exists",
				   $dest_filename);
    }
    if (!open(OUT, "> $dest_filename")) {
	return $e . $self->fmt_msg("msg_showeditor_create_error",
				   $dest_filename, $!);
    }
    binmode(OUT);

    my $fh = $filename;
    if (!$fh) {
	close(OUT);
	unlink $dest_filename;
	return $e . $self->msg("msg_showeditor_upload_cancelled");
    }
    while(<$fh>) {
	print OUT $_;
    }
    if (!close(OUT)) {
	return $e . $self->fmt_msg("msg_showeditor_close_error", $!);
    }
    return $self->fmt_msg("msg_showeditor_upload_success", $sane_filename);
}

sub showeditor_any_newfolder {
    my $self = shift;
    my($basedir) = @_;
    my $newfolder = param("newfoldername");
    my $e = $self->msg("msg_showeditor_mkdir_error") . ": ";
    if ($newfolder =~ /^\s*$/) {
	return $e . $self->msg("msg_showeditor_missing_dirname");
    }
    if (_invalid_file_name($newfolder) || $newfolder =~ /^\./) {
	return $e . $self->fmt_msg("msg_showeditor_invalid_dirname",
				   $newfolder);
    }
    $newfolder = _sane_file_name($newfolder);
    my $abs_folder = $basedir . "/" . $newfolder;
    if (-e $abs_folder) {
	return $e . $self->fmt_msg("msg_showeditor_dir_exists", $newfolder);
    }
    if (!mkdir($abs_folder, 0775)) {
	return $e . $!;
    }
    return $self->fmt_msg("msg_showeditor_mkdir_success", $newfolder);
}

sub showeditor_any_delete {
    my $self = shift;
    my($basedir) = @_;
    my $file = param("deletename");
    my $e = $self->msg("msg_showeditor_del_error") . ": ";
    if ($file =~ /^\s*$/) {
	return $e . $self->msg("msg_showeditor_missing_filename");
    }
    if (_invalid_file_name($file) || $file eq '.') {
	return $e . $self->fmt_msg("msg_showeditor_invalid_filename", $file);
    }
    my $abs_file = $basedir . "/" . $file;
    if (!-e $abs_file) {
	return $e . $self->fmt_msg("msg_showeditor_no_file", $file);
    }
    if (-d $abs_file) {
	my(@f) = glob("$abs_file/*");
	if (@f) {
	    return $e . $self->fmt_msg("msg_showeditor_nonempty_dir", $file);
	}
    }
    if (-d $abs_file) {
	if (!rmdir($abs_file)) {
	    return $e . $!;
	}
	return $self->fmt_msg("msg_showeditor_rmdir_success", $file);
    } else {
	if (!unlink($abs_file)) {
	    return $e . $!;
	}
	return $self->fmt_msg("msg_showeditor_del_success", $file);
    }
}

sub showeditor_any_rename {
    my $self = shift;
    my($basedir, %args) = @_;
    my $from = param("renamefrom");
    my $to   = param("renameto");
    my $e = $self->msg("msg_showeditor_rename_error") . ": ";
    if ($from =~ /^\s*$/ || $to =~ /^\s*$/) {
	return $e . $self->msg("msg_showeditor_missing_filenames");
    }
    if (_invalid_file_name($from)) {
	return $e . $self->fmt_msg("msg_showeditor_invalid_filename", $from);
    }
    if (_invalid_file_name($to)) {
	return $e . $self->fmt_msg("msg_showeditor_invalid_filename", $to);
    }
    require File::Basename;
    if ($to !~ m|/| && !-d "$basedir/$to") {
	$to = File::Basename::dirname($from) . "/" . $to;
    }
    my $abs_from = $basedir . "/" . $from;
    my $sane_to  = _sane_file_name($to);
    my $abs_to   = $basedir . "/" . $sane_to;
    if (!-e $abs_from) {
	return $e . $self->fmt_msg("msg_showeditor_no_file", $from);
    }
    if (-d $abs_to) {
	$abs_to .= "/" . File::Basename::basename($from);
	$sane_to .= "/" . File::Basename::basename($from);
    }
    if (-e $abs_to) {
	return $e . $self->fmt_msg("msg_showeditor_filename_exists", $sane_to)
    }
    if (!-d $abs_from) {
	if ($args{'-checkext'} eq 'image') {
	    if (!$self->_check_allowed_image_extensions($abs_to)) {
		return $e . $self->fmt_msg("msg_showeditor_invalid_ext",
					   join(", ", $self->_allowed_image_extensions()),
					   $abs_to
					  );
	    }
	}
    }
    if (File::Basename::basename($abs_to) =~ /^\./) {
	return $e . $self->msg("msg_showeditor_nodot_filename");
    }
    require File::Copy;
    if (!File::Copy::move($abs_from, $abs_to)) {
	return $e . $!;
    }
    $self->fmt_msg("msg_showeditor_rename_success", $from, $sane_to);
}

# object method
sub _allowed_image_extensions {
    qw(gif png jpg jpeg jpe tiff tif);
}

sub _check_allowed_image_extensions {
    my $self = shift;
    my $filename = shift;
    my $allowed_extensions = '\.(' . join("|", $self->_allowed_image_extensions()) . ")\$";
    if ($filename !~ /$allowed_extensions/) {
	return 0;
    } else {
	return 1;
    }
}

sub _invalid_file_name {
    my $file = shift;
    return 1 if $file =~ /(^|\/)\.\.($|\/)/;
}
sub _universal_basename {
    my $file = shift;
    if ($file =~ m|[/\\]([^/\\]+)$|) {
	$1;
    } else {
	$file;
    }
}
sub _sane_file_name {
    my $file = shift;
    # Umlaute korrigieren:
    my $convert = {'ä' => 'ae',
		   'ö' => 'oe',
		   'ü' => 'ue',
		   'Ä' => 'Ae',
		   'Ö' => 'Oe',
		   'Ü' => 'Ue',
		   'ß' => 'ss',
		  };
    my $convert_rx = "(".join("|",map {quotemeta} keys %$convert).")";
    $file =~ s/$convert_rx/$convert->{$1}/g;
    # "gefährliche" Zeichen umwandeln
    $file =~ s/[^A-Za-z0-9_.\/-]/_/g;
    $file;
}

sub showeditor_link {
    my $self = shift;
    if (param('elementtype') =~ /download/ && $self->can("showeditor_download")) {
	$self->showeditor_download($self->C);
    } else {
	$self->_tpl("bestwe", "we_linkeditor.tpl.html",
		    {
		     'elementtype' => param('elementtype')||'',
		    }
		   );
    }
}

######################################################################
#
# tree editor page
sub siteeditorframe {
    my $self = shift;
    my $message = shift;
    if (defined $message) {
	param("message" => $message);
    }
    my $c = $self->C;
    my $objdb = $self->Root->ObjDB;
    if (defined param("fromid") && param("fromid") ne "" &&
	$c->project->sessionlocking) {
	my $pageobj = $objdb->get_object(param("fromid"));
	if ($pageobj && $pageobj->LockedBy eq $self->User) {
	    $objdb->unlock($pageobj);
	}
    }
    $self->_tpl("bestwe", "we_folderreload.tpl.html",
		{
		 'folderid' => param("pageid") ||'',
		 'message'  => param("message")||'',
		}
	       );
}

######################################################################
#
# tree editor page
sub siteeditexplorer {
    my $self = shift;
    $self->_tpl("bestwe", "we_siteedit_explorer.tpl.html");
}

######################################################################
#
# tree editor page
# Return a javascript source line to create this object in a html tree.
sub show_children_line {
    my $self = shift;
    my($k,$level,$recursive) = @_;
    my $line = "";

    my $root = $self->Root;
    my $c = $self->C;

    if (!defined $k) {
	warn "*** SHOULD not happen (database corrupt?): \$k is undefined ***";
	return;
    }
    my $id = $k->Id;
    my $titlestr = $k->Title;
    my $title = "";
    # resolve Languagestring
    if (UNIVERSAL::isa($titlestr, 'WE::Util::LangString')) {
	$title = $titlestr->get($c->project->sitelanguages->[0]);
    } else {
	$title = $titlestr;
    }
    my $escapedTitle = _uri_escape($title);
    my $timeCreated = $k->TimeCreated;
    my $timeModified = $k->TimeModified;
    my $temp = $k->Release_State;
    my $releaseState;
    if (defined($temp) && $temp ne "") {
	$releaseState = $temp;
    }
    else {
	$releaseState = "modified";
    }

    my $inactive = defined $k->Release_State && $k->Release_State eq 'inactive' ? "1":"0";
## XXX It's not yet clear what "inactive" really means...
#     if (!$root->is_allowed("everything") && $inactive) {
# 	# inactive folders and documents are not visible to non-admins
# 	next;
#     }

    if ($k->is_folder) {
	local $^W = 0; # because of Rights =~ ...
	#my $nop = $k->Rights =~ /nopage/ ? "1":"0";
	#my $nof = $k->Rights =~ /nofolder/ ? "1":"0";
	my($nop, $nof);
	if ($root->is_allowed("everything")) {
	    $nop="0";$nof="0";
	} else {
	    $nop = $k->Rights =~ /nopage/ || !$root->is_allowed("new-doc",$k->Id) ? "1" : "0";
	    $nof = $k->Rights =~ /nofolder/ || !$root->is_allowed("new-folder", $k->Id) ? "1" : "0";
	}
	$line .= qq <e_trees[0].add({level:$level,name:$id,title:unescape("$escapedTitle"),nop:"$nop",nof:"$nof",inactive:"$inactive",timecreated:"$timeCreated",timemodified:"$timeModified",releaseState:"$releaseState"});\n >;
	$line .= $self->show_children($k,$level) if $recursive;
    }
    else {
	my $type = $k->{Type} || "";
	my $icon = $c->project->iconfortype && $c->project->iconfortype->{$type} ? $c->project->iconfortype->{$type} : "text";
	$line .= qq <e_trees[0].add({level:$level,id:$id,title:unescape("$escapedTitle"),name:$id,subpage:"$icon",timecreated:"$timeCreated",timemodified:"$timeModified",releaseState:"$releaseState"});\n >;
    }

    $line;
}

sub show_children {
    my $self = shift;
    my($obj,$level) = @_;
    my $pagelist = "";
    $level++;
    my $objdb = $self->Root->ObjDB;
    foreach my $k ($objdb->children($obj)) {
	$pagelist .= $self->show_children_line($k, $level, 1);
    }
    $pagelist;
}

sub siteedit {
    my $self = shift;
    $self->check_login;
    #XXX check here if user has the right rights...
    my $fromid = param("fromid");
    my $root = $self->Root;
    my $c    = $self->C;
    my $root_obj = $root->root_object;
    my $pagelist = $self->show_children_line($root_obj,0,0) .
	           $self->show_children($root_obj,0);

    $self->_tpl("bestwe", "we_site.tpl.html",
		{
		 siteinfobutton => $root->is_allowed("everything") || $root->is_allowed("site-info") ? 1:0,
		 publishbutton  => $root->is_allowed("publish") || $root->is_allowed("everything") ? 1:0,
		 pagelist       => $pagelist,
		 fromid         => $fromid,
		 pagetypes      => $c->project->pagetypes,
		 pagelabels     => $c->project->labelfortype,
		 hometitle      => $root_obj ? langstring($root_obj->Title, $self->EditorLang) : "",
		 nofolderview   => param("nofolderview")||0,
		 message        => param("message")||"",
		 new            => 1,
		}
	       );
}

######################################################################
#
# doc tree frameset
#
sub doctreeframe {
    my $self = shift;
    $self->_tpl("bestwe", "we_documenttreeframeset.tpl.html");
}

sub doctree {
    my $self = shift;
    #XXX check here if user has the right rights...
    my $message = shift || "";

    my $c        = $self->C;
    my $root     = $self->Root;
    my $root_obj = $root->root_object;

    my $pagelist = $self->show_children($root_obj,0);

    $self->_tpl("bestwe", "we_doctree_main.tpl.html",
		{
		 'pagelist'   => $pagelist,
		 'message'    => $message,
		 'pagetypes'  => $c->project->pagetypes,
		 'pagelabels' => $c->project->labelfortype,
		}
	       );
}

######################################################################
#
# search
sub search {
    my $self = shift;
    if (param("search") ne "") {
	# XXX actually implement it
	$self->_tpl("bestwe","we_searchresult.tpl.html");
    } else {
	$self->_tpl("bestwe","we_search.tpl.html");
    }
}

######################################################################
#
# move/copy frameset
sub movecopyframeset {
    my $self = shift;
    $self->_tpl("bestwe", "we_movecopy_frameset.tpl.html",
		{ cgidir   => $self->C->paths->cgiurl,
		  lang     => $self->EditorLang,
		  action   => param('action')||'',
		  sourceid => param('sourceid')||'',
		  title    => param('title')||'',
		});
}

######################################################################
#
# move/copy js frame
sub movecopyjs {
    my $self = shift;
    my $root = $self->Root;
    my $root_obj = $root->root_object;
    my $pagelist = $self->show_children($root_obj, 0);

    $self->_tpl("bestwe", "we_movecopy_js.tpl.html",
		{ pagelist => $pagelist,
		  action   => param('action')||"",
		  sourceid => param('sourceid')||"",
		  title    => CGI::unescape(param('title')),
		}
	       );
}

######################################################################
#
# move/copy explorer frame
sub movecopyexplorer {
    my $self = shift;
    $self->_tpl("bestwe", "we_movecopy_explorer.tpl.html");
}

######################################################################
#
# move/copy action
sub movecopyaction {
    my $self = shift;

    $self->check_login;

    my $sourceid = param('sourceid');
    die "No sourceid given" if !defined $sourceid;
    my $targetid = param('targetid');
    die "No targetid given" if !defined $targetid;
    my $action = param('action');
    die "Invalid action $action" if $action !~ /^(copy|move)$/;

    # The web.editor does not support objects under multiple parents,
    # but the WE_Framework does. If the support will ever be built in, then
    # here the parent id has also to be supplied for the move action.
    # See (*) below.

    my $root = $self->Root;
    my $objdb = $root->ObjDB;
    my $source_obj = $objdb->get_object($sourceid);
    my $folderid = ($objdb->parent_ids($source_obj))[0]; # (*) should be supplied
    my $error;
    if ($action eq 'move') {
	unless ((($source_obj->is_folder && $root->is_allowed("move-folder")) ||
		 ($source_obj->is_doc    && $root->is_allowed("move-doc")))
		&& $root->is_allowed("edit", $folderid)
		&& $root->is_allowed("edit", $sourceid)
	       ) {
	    die "No permission to move $sourceid to $targetid"
	}

	eval {
	    local $SIG{__DIE__};
	    $objdb->move($sourceid, undef, -destination => $targetid);
	};
	if ($@) {
	    warn $@;
	    $error = $@;
	}
    } else {
	unless ((($source_obj->is_folder && $root->is_allowed("copy-folder")) ||
		 ($source_obj->is_doc    && $root->is_allowed("copy-doc")))
		&& $root->is_allowed("edit", $folderid)
		&& $root->is_allowed("edit", $sourceid)
	       ) {
	    die "No permission to copy $sourceid to $targetid"
	}

	eval {
	    local $SIG{__DIE__};
	    my @copy_obj = $objdb->copy($sourceid, $targetid);
	    for my $copy_obj (@copy_obj) {
		my $need_replace;
		if ($source_obj->Release_State eq 'released') {
		    $copy_obj->Release_State("modified");
		    $need_replace++;
		}
		if (grep { $_ eq $targetid } $objdb->parent_ids($sourceid)) {
		    # XXX Maybe use numbering if there is something named
		    # "This Title (Copy)"
		    WE::Util::LangString::concat
			    ($copy_obj->Title,
			     new_langstring(de => " (Kopie)", en => " (Copy)")
			    );
		    $need_replace++;
		}
		if ($need_replace) {
		    $objdb->replace_object($copy_obj);
		}
	    }
	};
	if ($@) {
	    warn $@;
	    $error = $@;
	}
    }

    $self->_tpl("bestwe", "we_movecopy_action.tpl.html",
		{ folderid => $folderid,
		  error    => $error,
		}
	       );
}

######################################################################

sub _tpl {
    my($self, $type, $templatefile, $add_vars, $outfh) = @_;
    require Template;
    my $t = Template->new($self->TemplateConf);
    my $dir;
    my $c = $self->C;
    if ($type eq 'bestwe') {
	my @try_dirs = ($c->paths->site_we_templatebase,
			$c->paths->we_templatebase,
		       );
	for my $try_dir (@try_dirs) {
	    if (-r "$try_dir/$templatefile") {
		$dir = $try_dir;
		last;
	    }
	}
	if (!defined $dir) {
	    die "Can't find template $templatefile in directories: @try_dirs";
	}
    } elsif ($type eq 'we') {
	$dir = $c->paths->we_templatebase;
    } elsif ($type eq 'site') {
	$dir = $c->paths->site_templatebase;
    } elsif ($type eq 'site_we') {
	$dir = $c->paths->we_htmldir . "/" . $c->project->name . "_we_templates";
    } else {
	die "Invalid type $type for _tpl";
    }

    # Only for heavy debugging:
    local $Template::Plugins::DEBUG = 1 if defined $c->debug && $c->debug >= 10;

    $outfh = \*STDOUT if !defined $outfh;

#    local $SIG{__DIE__} = undef;
    $t->process("$dir/$templatefile",
		{ %{ $self->TemplateVars },
		  ($add_vars ? %$add_vars : ()),
		},
		$outfh
	       )
	or do {
	    die "Template process for $dir/$templatefile failed: "
		. $t->error . ", \@INC is @INC, pid is $$, Template dump: "
		. $t->context->_dump;
	};
}

sub error {
    my $self    = shift;
    my $message = shift;
    eval { $message = _html($message) };
    my $c = $self->C;
    my $developermail = 'eserte@users.sourceforge.net';
    if ($c) {
	eval { $developermail = _html($c->project->developermail) };
    }
    unless ($self->HeaderPrinted) {
	if (defined &header) { # CGI already loaded?
	    print header(); # no myheader needed here...
	} else { # fallback
	    print "Content-type: text/html\r\n\r\n";
	}
    }

    my @caller_info;
    for my $i (1 .. 20) {
	local $^W = 0;
	my(@info) = caller($i);
	if (!defined $info[0]) {
	    last;
	}
	push @caller_info, "$info[0] in $info[1]:$info[2]";
    }
    my $caller_info = "Can't get caller information";
    eval { $caller_info = _html(join("\n", @caller_info)) };

    my $context;
    eval {
	my @context;
	my $row = sub {
	    push @context, "<tr><td>" . _html($_[0]) ." =&gt;</td><td>"
		. _html($_[1]) . "</td></tr>";
	};
	for my $k (sort keys %$self) {
	    my $v = $self->{$k};
	    if ($k eq 'Password') {
		$row->($k, "********");
	    } else {
		$row->($k, $v);
	    }
	}
	my @param = param();
	for my $param (sort @param) {
	    if ($param eq 'password') {
		$row->("(CGI) $param", "********");
	    } else {
		$row->("(CGI) $param", param($param));
	    }
	}
	$context = "Context:<br><table border=0 cellpadding=0 cellspacing=0>" . join("\n", @context) . "</table>";
    };

    my $version = '$Id: OldController.pm,v 1.84 2005/02/23 13:13:59 eserte Exp $';

    my $stylesheet;
    eval {
	$stylesheet='<link rel="stylesheet" type="text/css" href="' .
	    $c->paths->we_htmlurl . "/styles/cms.css"
	    .'" />';
    };

    print <<EOF;
<html>
 <head>
  <title>ERROR</title>
$stylesheet
 </head>
<body class="oops">
<hr/>
<h1>Ooops!</h1>
<div class="quote">
 Three things are certain:<br>
 Death, taxes, and lost data.<br>
 Guess which has occurred.<br>
 <br></div>
 -- David Dixon <br><br>
 Please send the content of this page to:
 <a href="mailto:$developermail">$developermail</a><br><br><tt>
 <span class="error">$message<br>
 \$!: $! (&lt;= may be irrelevant)</span>
 in<br>
<pre>
$caller_info
</pre>
$context<br>
Version: $version<br>
 </tt><br><br><br>
</body></html>
EOF
    exit();
}

sub _dump_outdata {
    my($self, $obj) = @_;
    my $content_dumper = $self->ContentDumper;
    eval "require $content_dumper"; die $@ if $@;
    my $c_o = $content_dumper->new(-object => $obj);
    $c_o->serialize;
}

sub _get_outdata {
    my($self, $data, $dumper) = @_;
    if (!defined $data) {
	$data = param("data");
    }
    if (!defined $data || $data eq '') {
	die "`data' parameter is missing";
    }
    if (!defined $dumper) {
	require WE_Content::Base;
	$dumper = "WE_Content::Base";
    }
    my $c_o = $dumper->new(-string => $data);
    $c_o->{Object};
}

sub _get_pagetype {
    my $self = shift;
    my $pagetype = shift;
    if (!defined $pagetype) {
	$pagetype = param('pagetype') || 'new'; # XXX new?
    }
    # make it safe:
    if ($pagetype !~ /^[a-zA-Z0-9_.-]+$/) {
	die "Invalid characters in pagetype (only characters, numbers, dot, dash and underline allowed";
    }
    $pagetype;
}

# Return error message or undef
sub _ambiguous_name_message {
    my($self, $new_name, $old_object) = @_;
    return if (!$new_name);
    return if ($old_object->Name eq $new_name);
    # XXX langres
    if ($new_name =~ /^\d/) {
	return $self->msg("msg_name_no_leading_digit");
    }
    if ($new_name =~ /[^a-zA-Z0-9_-]/) {
	return $self->msg("msg_name_word_chars");
    }
    if ($new_name eq 'index') {
	return $self->msg("msg_name_index_reserved");
    }
    my $root = $self->Root;
    my $namedb = $root->NameDB;
    if ($namedb->exists($new_name)) {
	my $name_objid = $namedb->get_id($new_name);
	return $self->fmt_msg("msg_name_exists", $new_name, $name_objid);
    }
    undef;
}

sub _js_status_str {
    my($message) = @_;
    "onmouseover='self.status=unescape(\"$message\"); return true;' onmouseout='self.status=\"\"; return true;'";
}

sub _html_method { shift; _html($_[0]) }

sub _html {
    require HTML::Entities;
    if (defined &HTML::Entities::encode_entities_numeric) { # since 1.27
	HTML::Entities::encode_entities_numeric($_[0]);
    } else {
	HTML::Entities::encode_entities($_[0]);
    }
}

sub _uri_escape {
    require WE::Util::Escape;
    WE::Util::Escape::uri_escape($_[0]);
}

sub msg {
    my($self, $key) = @_;
    my $stash = $self->Messages->{$self->EditorLang};
    if (!$stash) {
	my $c = $self->C;
	my @try_langs = ($self->EditorLang);
	push @try_langs, "en" if $self->EditorLang ne "en";
	for my $lang (@try_langs) {
	    my $langres_file = $c->paths->we_templatebase . "/langres_$lang";
	    if (-r $langres_file) {
		require Template::Context;
		my $ctx = Template::Context->new({ ABSOLUTE => 1});
		$ctx->process($langres_file);
		$stash = $ctx->stash;
		last if $stash;
	    }
	}
	if (!$stash) {
	    return "[[$key]]";
	}
	$self->Messages->{$self->EditorLang} = $stash;
    }
    my $val = $stash->get($key);
    if (!defined $val) {
	"[[$key]]";
    } else {
	$val;
    }
}

sub fmt_msg {
    my($self, $key, @arg) = @_;
    sprintf $self->msg($key), @arg;
}

sub identify {
    my $self = shift;
    my $c = $self->C;
    my $root = $self->Root;
    if ($c && $c->siteext && $c->siteext->external_auth) {
	$root->CurrentUser(remote_user());
	return 1;
    } else {
	my($user, $password) = @_ ? @_[0, 1] : ($self->User, $self->Password);
	$root->identify($user, $password);
    }
}

sub current_user {
    my $self = shift;
    if (!$self->Root->CurrentUser) {
	$self->identify;
    }
    $self->Root->CurrentUser;
}

sub get_session {
    my($self, $sid) = @_;
    my $c = $self->C;
    my $sessdef = $c->siteext->{session};
    eval q{local $SIG{__DIE__}; require } . $sessdef->{module}; die $@ if $@;
    tie my %sess, $sessdef->{module}, $sid,
	{
	 FileName      => $sessdef->{FileName},
	 LockDirectory => $sessdef->{LockDirectory},
	}
	    or die "Can't get session: $!";
    \%sess;
}

sub delete_session {
    my($self, $sid) = @_;
    my $sessref = $self->get_session($sid);
    tied(%$sessref)->delete;
}

sub get_die_handler {
    my $oc = shift;
    return sub {
	die @_ if $^S; # we're in an eval

	my $stack_i = 1;
	while($stack_i < 200) {
	    my @c = caller($stack_i);
	    last if !@c;
	    # Another exception is any THROW call from the Template-Toolkit
	    if ($c[3] =~ m{^Template::.*::throw$}) {
		die @_;
	    }
	    $stack_i++;
	}
	$oc->error($_[0]);
    };
}

sub has_timebasedpublishing {
    my $self = shift;
    my $c = $self->C;
    $c->project->features->{timebasedpublishing};
}

sub get_we_template_contenttype {
    shift->get_template_contenttype(@_);
}

sub get_template_contenttype {
    my($self, $templatefile) = @_;
    my $content_type = "text/html";
    my $ext = ".html";
    if ($templatefile =~ /\.wml$/) {
	$content_type = "text/vnd.wap.wml";
	$ext = ".wml";
    } elsif ($templatefile =~ /\.js$/) {
	$content_type = "application/x-javascript";
	$ext = ".js";
    }
    ($content_type, $ext);
}

sub get_custom_userdb {
    my($self, $useradmindb) = @_;
    die if !$useradmindb;
    if ($self->CustomUserDB &&
	$self->CustomUserDB->{$useradmindb}) {
	return $self->CustomUserDB->{$useradmindb};
    }

    my $root = $self->Root;
    my $c = $self->C;
    my($userdb_basename, $userdb_newparam);
    if ($c->project->features->{userdb} &&
	$c->project->features->{userdb}{$useradmindb}) {
	my $userdb_prop = $c->project->features->{userdb}{$useradmindb};
	$userdb_basename = $userdb_prop->{basename};
	$userdb_newparam = $userdb_prop->{newparam};
    } else {
	my $userdb_prop = $root->get_userdb_prop($useradmindb);
	$userdb_basename = $userdb_prop->_basename;
	$userdb_newparam = $userdb_prop->_newparam;
    }
    require WE::DB::ComplexUser;
    my $u = WE::DB::ComplexUser->new
	(undef,
	 $c->paths->we_database . "/" . $userdb_basename,
	 @{ $userdb_newparam },
	 -locking => 1,
	 -connect => exists $ENV{MOD_PERL} ? 0 : 1,
	);
    $self->CustomUserDB->{$useradmindb} = $u;
    eval {
	require Scalar::Util;
	Scalar::Util::weaken($u);
    };
    if ($@) {
	warn "Weakening failed --- what about older perls? $@";
    }
    $u;
}

sub get_alias_pages {
    my($self, $id, %args) = @_;
    my $now   = $args{-now};
    my $root  = $self->Root;
    my $objdb = $root->ObjDB;
    my $c     = $self->C;

    my @alias_pages;
    push @alias_pages, $root->NameDB->get_names($id);

    # XXX Handle other cases, too (autoindexdoc ne "first" ...)
    my $autoindexdoc = $c->project->features->{autoindexdoc};
    if (defined $autoindexdoc && $autoindexdoc eq 'first') {
	my $o = $objdb->get_object($id);
	if ($o->is_folder) {
	    my(@children_ids) = $objdb->get_released_children($id, -now => $now);
	    if (@children_ids) {
		push @alias_pages, $children_ids[0]->Id;
	    }
	} else {
	    my($parent_id) = $objdb->parent_ids($id);
	    if (defined $parent_id) {
		my(@children_ids) = $objdb->get_released_children($parent_id, -now => $now);
		if ($children_ids[0]->Id eq $id) {
		    push @alias_pages, $parent_id, $self->get_alias_pages($parent_id, %args);
		}
	    }
	}
    }

    # make unique
    my %alias_pages = map {($_=>1)} grep { $_ ne $id } @alias_pages;
    keys %alias_pages;
}

sub we_notify {
    my($self, $action, $info) = @_;
    my $msg;
    if ($self->can('notify')) {
	my $retinfo = {};
	$self->notify($action, $info, $retinfo);
	if ($retinfo->{message}) {
	    $msg = $retinfo->{message};
	} elsif ($retinfo->{receivers} && @{$retinfo->{receivers}}) {
	    $msg = $self->fmt_msg("msg_notify_sent", "@{$retinfo->{receivers}}");
	}
    }
    $msg;
}

### XXX Ueberdenken. Insbesondere sollte mehr Information zurueckgegeben
### werden (symlink advised, folderindex page advised etc.)
### Am Ende wird diese Funktion viele "code doubled"-Stuecke hier
### und anderswo ersetzen.
# sub get_content_objectid {
#     my($self, $obj) = @_;
#     my $root = $self->Root;
#     my $objdb = $root->ObjDB;
#     my $c = $self->C;
#     $objdb->objectify_params($obj);
#     if ($obj->is_folder) {
# 	my $docid = $obj->IndexDoc;
# 	if (!defined $docid || $docid eq "") {
# 	    my $mainid = $obj->Version_Parent;
# 	    $mainid = $obj->Id if !defined $mainid;
# 	    my $autoindexdoc = $c->project->features->{autoindexdoc};
# 	    if (defined $autoindexdoc && $autoindexdoc eq 'first') {
# 		my(@children_ids) = $objdb->get_released_children($mainid, -now => $now);
# 		if (@children_ids) {
# 		    return $children_ids[0]->Id;
# 		}
# 	    }
# 	    # else: folderindex template will be used
# 	    return undef;
# 	} else {
# 	    return $docid;
# 	}
#     } else { return $obj->Id }
# }

1;

__END__
