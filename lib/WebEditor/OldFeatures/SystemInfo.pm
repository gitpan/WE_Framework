# -*- perl -*-

#
# $Id: SystemInfo.pm,v 1.10 2005/01/10 08:30:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://www.sourceforge.net/projects/we-framework
#

package WebEditor::OldFeatures::SystemInfo;

=head1 NAME

WebEditor::OldFeatures::SystemInfo - return system information

=head1 SYNOPSIS

   use mixin 'WebEditor::OldFeatures::SystemInfo';
   print $self->system_info_as_html();

=head1 DESCRIPTION

This module returns information about the current system.

=head1 CAVEATS

This module may return too much information about the system, e.g.
system passwords which are stored in cookies or configuration objects.
You should not let unauthorized users to call this feature!

=head1 AUTHOR

Slaven Rezic

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

sub system_info_as_html {
    my($self, %args) = @_;

    local $Data::Dumper::Sortkeys = 1;

    my $uname_a = eval { `uname -a` };

    my $linux_release = "";
    eval {
	my @release_f = glob("/etc/*-release");
	for my $f (@release_f) {
	    if (open(F, $f)) {
		local $/ = undef;
		# Can't do this in one line (problem only apparent with
		# perl5.8.0 and mod_perl operation, but not cgi operation)
		my $add = <F>;
		$linux_release .= $add;
		close F;
	    }
	}
    };
    if ($@) {
	$linux_release .= $@;
    }
    if ($linux_release ne "") {
	$linux_release = <<EOF;
Linux distribution version (if applicable):
$linux_release
EOF
    }


    my $perl_version = "perl $]\n";
    eval {
	require Config;
	$perl_version .= Config::myconfig();
	$perl_version .= "\n\@INC:\n" . join(",\n", map { "\t$_" } @INC);
    };
    $perl_version .= $@ if $@;

    my $apache_version = $ENV{SERVER_SOFTWARE};

    my $operation_mode;
    if ($ENV{MOD_PERL}) {
	$operation_mode .= "Running under mod_perl ($ENV{GATEWAY_INTERFACE})\n";
	if (!$self->R) {
	    $operation_mode .= "Probably Apache::Registry or similar operation mode.\n";
	}
    } else {
	$operation_mode .= "Running as cgi-bin ($ENV{GATEWAY_INTERFACE})\n";
    }

    my $get_versions;
    $get_versions = sub {
	my($module, $no_recurse, $level) = @_;
	$level = 1 if !defined $level;
	return if $level >= 5; # recursion breaker
	my @versions;
	no strict 'refs';
	if (defined ${$module . "::VERSION" }) {
	    push @versions, [ $module => ${$module . "::VERSION" } ];
	}
	if (!$no_recurse) {
	    for my $sym (keys %{$module . "::"}) {
		if ($sym =~ /(.*)::$/) {
		    $sym = $1;
		    push @versions, $get_versions->($module . "::" . $sym, undef, $level+1);
		}
	    }
	}
	@versions;
    };

    my $perlmod_versions = "";
    my @perlmod_toplevel_modules =
	(qw(Apache CGI Template Data::JavaScript));
    eval {
	my @perlmod_versions;
	for my $top (@perlmod_toplevel_modules) {
	    push @perlmod_versions, $get_versions->($top, "norecurse");
	}
	for my $v (sort { $a->[0] cmp $b->[0] } @perlmod_versions) {
	    my($module, $version) = @$v;
	    $perlmod_versions .= "  $module $version\n";
	}
    };
    $perlmod_versions .= $@ if $@;

    my $we_versions = "";
    my @toplevel_modules =
	(qw(WE WebEditor WE_Content WE_Frontend
	    WE_Multisite WE_Sample WE_Singlesite));
    push @toplevel_modules, "WE_" . $self->C->project->name;
    eval {
	my @we_versions;
	for my $top (@toplevel_modules) {
	    push @we_versions, $get_versions->($top);
	}
	for my $v (sort { $a->[0] cmp $b->[0] } @we_versions) {
	    my($module, $version) = @$v;
	    $we_versions .= "  $module $version\n";
	}
    };
    $we_versions .= $@ if $@;

    my $config_object;
    my $current_user;
    eval {
	require Data::Dumper;
	$config_object .= Data::Dumper::Dumper($self->C);
	$current_user = "Current user is `" . $self->User . "'.\n";
    };
    $config_object .= $@ if $@;

    my $database_status;
    eval {
	my $objdb = $self->Root->ObjDB;
	my $contentdb = $self->Root->ContentDB;
	$database_status = "The Object database has " . $objdb->count . " objects.\n";

	require WE::Util::Support;
	require Data::Dumper;

	my $errors = $objdb->check_integrity($contentdb);
	my $contentdb_errors = $contentdb->check_integrity($objdb);

	$database_status .= "we_fsck returned:\n" . Data::Dumper::Dumper($errors, $contentdb_errors);

    };
    $database_status .= $@ if $@;

    my $template_config = "";
    eval {
	require Data::Dumper;
	$template_config .= Data::Dumper::Dumper($self->TemplateConf);
    };
    $template_config .= $@ if $@;

    my $template_vars = "";
    eval {
	while(my($k,$v) = each %{ $self->TemplateVars }) {
	    $template_vars .= "\t$k => $v,\n";
	}
    };
    $template_vars .= $@ if $@;

    <<EOF
<div class="systeminfo">
<div>
Unix system:
$uname_a
</div>
EOF
	. ($linux_release ne "" ? <<EOF : "")
<div>
$linux_release
</div>
EOF
	    . <<EOF
<div>
Apache:
$apache_version
$operation_mode
</div>
<div>
Perl version:
$perl_version
</div>
<div>
Perl module versions:
$perlmod_versions
</div>
<div>
WE versions:
$we_versions
</div>
<div>
WebEditor config object:
$config_object
</div>
<div>
Template-Toolkit config:
$template_config
</div>
<div>
Template-Toolkit variables:
$template_vars
</div>
<div>
$current_user
</div>
<div>
Database status:
$database_status
</div>
</div>
<hr />
EOF
		;
}

1;
