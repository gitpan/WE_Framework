# -*- perl -*-

#
# $Id: AtJobManager.pm,v 1.4 2004/06/09 06:11:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package WE::Util::AtJobManager;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw(Class::Accessor);

use WE::Util::Functions qw(is_in_path);

__PACKAGE__->mk_accessors(qw(at_path at_queue));

sub new {
    my($class, @args) = @_;
    my $self = bless {}, $class;
    $self->init(@args);
    $self;
}

sub init {
    my($self, %args) = @_;
    if (!$self->at_path) {
	my $path = is_in_path("at");
	if (!$path) {
	    $path = "/usr/bin/at";
	    undef $path if (!-x $path);
	}
	die "Can't find `at' command" if !$path;
	$self->at_path("at");
    }

    my $queue = $args{queue} || "c";
    $self->at_queue($queue);
}

sub start_job {
    my($self, $time, $command, $args) = @_;
    my @cmd = $command;
    if ($args) {
	push @cmd, @$args;
    }
    if (!@cmd) {
	die "No command supplied";
    }

    $time = $self->_epoch_to_crontime($time);

    my @at_cmd = $self->at_path;
    if ($self->at_queue) {
	push @at_cmd, "-q" =>  $self->at_queue;
    }
    push @at_cmd, $time;
    my $pid_status;
    local $SIG{CHLD} = sub { $pid_status = $? }; # linux reaps by default
    local $SIG{PIPE} = "IGNORE";
    my $pid = open(AT, "|-") or do {
	warn "@at_cmd\n";
	exec @at_cmd;
	die "Can't run @at_cmd: $!";
    };
    warn "@cmd\n";
    print AT "@cmd\n";
    close AT;
    waitpid($pid, 0);
    if ($pid_status != 0) {
	die "at job <pid=$pid> failed to start and returned exit code $pid_status";
    }
}

sub list_jobs {
    my $self = shift;

    require Time::Local;

    my @jobs;
    my $queue = $self->at_queue;
    open(ATQ, $self->at_path . " -l -q $queue |")
	or die "Can't call at -l";
    while(<ATQ>) {
	chomp;
	my($jobnr, $date, $time, $queue, $user) = split /\s+/;
	my($Y,$M,$D) = split /-/, $date;
	my($h,$m) = split /:/, $time;
	my $epoch = Time::Local::timelocal(0, $m, $h, $D, $M-1, $Y-1900);
	push @jobs, {jobnumber => $jobnr,
		     date      => $date,
		     time      => $time,
		     queue     => $queue,
		     user      => $user,
		     epoch     => $epoch,
		    };
    }
    close ATQ;
    @jobs;
}

sub delete_job {
    my($self, $jobnr) = @_;
    system($self->at_path, "-d", $jobnr);
}

sub check_daemon {
    my $self = shift;
    my $atd_running = $self->_check_process("atd");
    return 1 if $atd_running;

    if ($^O =~ /bsd/i) {
	my $cron_running = $self->_check_process("cron");
	return 0 if !$cron_running;

	my $found_atrun;
	open(CRONTAB, "/etc/crontab") or die "Can't open crontab: $!";
	while(<CRONTAB>) {
	    m{/usr/libexec/atrun} and do {
		$found_atrun = 1;
		last;
	    }
	}
	close CRONTAB;
	return 1 if $found_atrun;

	die "Can't find atrun entry in /etc/crontab";
    }

    0;
}

sub restart_daemon {
    if (-x "/etc/init.d/atd") {
	system "/etc/init.d/atd", "start";
	return $? == 0;
    }

    if ($^O =~ /bsd/i) {
	system "/usr/sbin/cron";
	return $? == 0;
    }

    die "Don't know how to restart the atd/crond daemon";
}

sub _check_process {
    my($self, $procname) = @_;
    if (open(PID, "/var/run/$procname.pid")) {
	chomp(my $pid = <PID>);
	close PID;
	if (defined $pid) {
	    if (kill 0 => $pid or $!{EPERM}) {
		return 1;
	    } else {
		return 0;
	    }
	}
    }
    return 0;
}

sub _epoch_to_crontime {
    my($self, $time) = @_;

    my @l = localtime $time;
    $l[4]++;
    $l[5]+=1900;
    sprintf "%02d:%02d %02d.%02d.%04d", @l[2,1,3,4,5];
}

return 1 if caller;

my $ajm = __PACKAGE__->new;
my $method = shift;
if ($method eq 'start_job') {
    $ARGV[2] = [ splice @ARGV, 2 ];
}
my @res = $ajm->$method(@ARGV);
require Data::Dumper;
print "The result is:\n" . Data::Dumper::Dumper(@res) . "\n";

__END__
