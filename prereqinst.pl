#!/usr/bin/env perl
# -*- perl -*-
#
# DO NOT EDIT, created automatically by
# /home/e/eserte/bin/sh/mkprereqinst
# on Sat Jan 29 22:02:14 2005
#
# Run this script as
#    perl prereqinst.pl
#
# The latest version of mkprereqinst may be found at
#     http://www.perl.com/CPAN-local/authors/id/S/SR/SREZIC/
# or any other CPAN mirror.

use Getopt::Long;
my $require_errors;
my $use = 'cpan';
my $q;

if (!GetOptions("ppm"  => sub { $use = 'ppm'  },
		"cpan" => sub { $use = 'cpan' },
                "q"    => \$q,
	       )) {
    die "usage: $0 [-q] [-ppm | -cpan]\n";
}

$ENV{FTP_PASSIVE} = 1;

if ($use eq 'ppm') {
    require PPM;
    do { print STDERR 'Install File-Spec'.qq(\n); PPM::InstallPackage(package => 'File-Spec') or warn ' (not successful)'.qq(\n); } if !eval 'require File::Spec; File::Spec->VERSION(0.8)';
    do { print STDERR 'Install Data-Dumper'.qq(\n); PPM::InstallPackage(package => 'Data-Dumper') or warn ' (not successful)'.qq(\n); } if !eval 'require Data::Dumper; Data::Dumper->VERSION(2.121)';
    do { print STDERR 'Install MLDBM'.qq(\n); PPM::InstallPackage(package => 'MLDBM') or warn ' (not successful)'.qq(\n); } if !eval 'require MLDBM';
    do { print STDERR 'Install mixin'.qq(\n); PPM::InstallPackage(package => 'mixin') or warn ' (not successful)'.qq(\n); } if !eval 'require mixin';
    do { print STDERR 'Install DB_File-Lock'.qq(\n); PPM::InstallPackage(package => 'DB_File-Lock') or warn ' (not successful)'.qq(\n); } if !eval 'require DB_File::Lock';
    do { print STDERR 'Install DB_File'.qq(\n); PPM::InstallPackage(package => 'DB_File') or warn ' (not successful)'.qq(\n); } if !eval 'require DB_File';
    do { print STDERR 'Install Class-Accessor'.qq(\n); PPM::InstallPackage(package => 'Class-Accessor') or warn ' (not successful)'.qq(\n); } if !eval 'require Class::Accessor';
} else {
    use CPAN;
    if (!eval q{ CPAN->VERSION(1.70) }) {
	install 'CPAN';
        CPAN::Shell->reload('cpan');
    }
    install 'File::Spec' if !eval 'require File::Spec; File::Spec->VERSION(0.8)';
    install 'Data::Dumper' if !eval 'require Data::Dumper; Data::Dumper->VERSION(2.121)';
    install 'MLDBM' if !eval 'require MLDBM';
    install 'mixin' if !eval 'require mixin';
    install 'DB_File::Lock' if !eval 'require DB_File::Lock';
    install 'DB_File' if !eval 'require DB_File';
    install 'Class::Accessor' if !eval 'require Class::Accessor';
}
if (!eval 'require File::Spec; File::Spec->VERSION(0.8);') { warn $@; $require_errors++ }
if (!eval 'require Data::Dumper; Data::Dumper->VERSION(2.121);') { warn $@; $require_errors++ }
if (!eval 'require MLDBM;') { warn $@; $require_errors++ }
if (!eval 'require mixin;') { warn $@; $require_errors++ }
if (!eval 'require DB_File::Lock;') { warn $@; $require_errors++ }
if (!eval 'require DB_File;') { warn $@; $require_errors++ }
if (!eval 'require Class::Accessor;') { warn $@; $require_errors++ }

if (!$require_errors) { warn "Autoinstallation of prerequisites completed\n" unless $q } else { warn "$require_errors error(s) encountered while installing prerequisites\n" } 
