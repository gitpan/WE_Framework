package WebEditor::OldFeatures::AdminGroup;

use strict;
use vars  qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use mixin::with 'WebEditor::OldController';

use CGI qw(param);

sub groupadmin {
    my $self = shift;

    $self->check_login;
    my $root = $self->Root;

    my @needed_permissions = qw(admin groupadmin);
    if (!$root->is_allowed([@needed_permissions])) {
	print <<EOF;
You are not allowed to call the group administration interface! You
ermineed one of the following permissions: @needed_permissions.<p>
Back to <a href='javascript:history.back()'>admin</a> page.
EOF
	exit;
    }

    my $c = $self->C;
    my %tplvars;

    my $u;
    my $useradmindb = param('useradmindb') || '';
    my $userdb_prop;
    if ($useradmindb eq '') {
	$u = $root->UserDB;
	if ($root->can('get_userdb_prop')) {
	    $userdb_prop = $root->get_userdb_prop("");
	}
    } else {
	$u = $self->get_custom_userdb($useradmindb);
    }
    if (!$u) {
	$self->error("No userdb for $useradmindb defined");
    }

    my @message;
    my $useradminaction	  = param('useradminaction');
    my $useradmingroup	  = param('useradmingroup');
    my $useradmindelgroup = param('useradmindelgroup');

    my $groupinfo_update = sub {
	my %new;
	foreach my $key (param()) {
	    next unless $key =~ /^useradmingroup_(.*)/;
	    my $fieldkey = $1;
	    my $val = param($key);
	    $new{$fieldkey} = $val;
	}
	if (keys %new) {
	    my $groupobj = $u->get_group_definition($useradmingroup);
	    @{$groupobj}{keys %new} = values %new;
	    $u->set_group_definition($useradmingroup, $groupobj);
	}

	if ($c->project->features->{wwwauth}) {
	    # XXX passing -userdb not necessary anymore?
	    $self->update_auth_files(-verbose => 0, -userdb => $u)
		if $useradmindb && $self->can("update_auth_files");
	}
    };

    $useradminaction = "" if !defined $useradminaction;

    if ($useradminaction eq "addgroup") {
	if ($useradmingroup =~ /^\s*$/) {
	    push @message, qq{<span class="alert">Error: no group given!</span>};
	} else {
	    if ($u->add_group_definition($useradmingroup) == 1) {
		$groupinfo_update->();
		push @message, "Group $useradmingroup successfully added.";
	    } else {
		push @message, qq{<span class="alert">Could not add group $useradmingroup</span>};
	    }
	}
    } elsif ($useradminaction eq "updgroup") {
	$groupinfo_update->();
    } elsif ($useradminaction eq "delgroup") {
	if ($u->delete_group_definition($useradmindelgroup) == 1) {
	    push @message, "Group $useradmindelgroup successfully deleted.";
	} else {
	    push @message, qq{<span class="alert">Could not delete group $useradmindelgroup</span>};
	}
    } elsif ($useradminaction eq "editgroup") {
	my $groupobj;
	if ($groupobj = $u->get_group_definition($useradmingroup)) {
	    push @message, "Please edit group $useradmingroup.";
	    $tplvars{'group'} = $groupobj;
	} else {
	    push @message, qq{<span class="alert">Could not get group data for $useradmingroup</span>};
	}
    }
    # Other group fetching mechanisms like in the user administration not
    # possible here.
    my @allgroups = $u->get_all_groups;
    $tplvars{'allgroups'} = \@allgroups;

    my @groupusers;
    if ($useradmingroup) {
	@groupusers = $u->get_users_of_group($useradmingroup);
    }

    # process Template
    $tplvars{'useradmindb'} = $useradmindb;
    $tplvars{'useradmingroup'} = $useradmingroup;
    $tplvars{'useradmingroupusers'} = \@groupusers;
    $tplvars{'message'} = join "\n", @message;
    $tplvars{'headline'} = $self->msg($useradmindb eq 'wwwuser' ? "cap_webgroupadmin" : "cap_groupadmin");
    $tplvars{'userheadline'} = $self->msg($useradmindb eq 'wwwuser' ? "cap_webuseradmin" : "cap_useradmin");

    $self->_tpl("bestwe", "we_groupadmin.tpl.html", \%tplvars);
}

1;
