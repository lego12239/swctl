#!/usr/bin/perl -W -I. -I/opt/swctl
#
# command line utility for controlling snmp devices
#
# Copyright (C) 2014  Oleg Nemanov <lego12239@yandex.ru>, Cifrabar group
# Copyright (C) 2015  Oleg Nemanov <lego12239@yandex.ru>, Cifrabar group
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use parse_cmd;
use Net::SNMP;
use Data::Dumper;


use constant {
    SNMP_COMMUNITY => "private",
    SNMP_VERSION => "2",
    VERSION => "0.2.1"
};


my $ipaddr;
my $cmd_defs = {
    opts => {
	"--save" => {
	    type => "bool",
	    alias => "-s" },
	"--verbose" => {
	    type => "bool",
	    alias => "-v" }
    },
    cmds => {
	help => {},
	"ip/help" => {},
	version => {},
	"ip/bind/set" => {
	    args => {
		addr => { type => "str",
			  mand => 1 },
		port => { type => "int",
			  mand => 1 }
	    }
	},
	"ip/bind/rm" => {
	    mand_any => 1,
	    args => {
		addr => { type => "str" },
		port => { type => "int" }
	    }
	},
	"ip/bind/show" => {
	    args => {
		addr => { type => "str" },
		port => { type => "int" }
	    }
	}
    }
};
my $pcmd;
my $acts = { help => \&output_help,
	     "ip/help" => \&output_ip_help,
	     version => \&output_version,
	     "ip/bind/show" => \&do_ip_bind_show,
	     "ip/bind/set" => \&do_ip_bind_set,
	     "ip/bind/rm" => \&do_ip_bind_rm };


sub errexit
{
    my ($msg, $code) = @_;


    print(STDERR $msg."\n");
    exit($code);
}

sub get_sw
{
    my ($ipaddr) = @_;
    my $sw;
    my $snmp;
    my $ret;
    my ($name, $sname);
    my $err;


    ($snmp, $err) = Net::SNMP->session(-hostname => $ipaddr,
				       -community => SNMP_COMMUNITY,
				       -version => SNMP_VERSION);
    if ( ! defined($snmp) ) {
	errexit("SNMP error: $err", 1);
    }

    # Get sysDescr.0
    $ret = $snmp->get_request(-varbindlist => ["1.3.6.1.2.1.1.1.0"]);
    if ( ! defined($ret) ) {
	errexit("SNMP error: ".$snmp->error(), 1);
    }
    $name = $ret->{"1.3.6.1.2.1.1.1.0"};
    $sname = $name;
    $sname =~ s/^(\S+)\s.*$/$1/o;
    $name =~ s/[^A-Za-z0-9_]/_/go;
    $sname =~ s/[^A-Za-z0-9_]/_/go;

    # Try module with a full name
    eval('use sw::'.$name.'; '.
	 '$sw = sw::'.$name.'->new(ipaddr => $ipaddr, '.
	 'snmp_community => "'.SNMP_COMMUNITY.'", '.
	 'snmp_version => "'.SNMP_VERSION.'", '.
	 'debug => 0);'); # may be 2
    if ( $@ ) {
	# Try module with a short name
	eval('use sw::'.$sname.'; '.
	     '$sw = sw::'.$sname.'->new(ipaddr => $ipaddr, '.
	     'snmp_community => "'.SNMP_COMMUNITY.'", '.
	     'snmp_version => "'.SNMP_VERSION.'", '.
	     'debug => 0);'); # may be 2
	if ( $@ ) {
	    errexit("Error during sw::$sname object creation: ".$@, 1);
	}
	$name = $sname;
    }

    return { sw => $sw,
	     name => $name };
}

sub output_help
{
    my $pname = $0;


    $pname =~ s/^.*\/([^\/]+)$/$1/o;
    print("Usage: $pname [OPTIONS] COMMAND IP\n\n".
	  "OPTIONS:\n".
	  " -s, --save     output in a format that can be executed later \n".
	  "                to restore settings\n".
	  " -v, --verbose  be more verbose\n\n".
	  "COMMAND:\n".
	  " help     show this help\n".
	  " version  show a version of $pname\n".
	  " ip       ip related actions ('ip help' to see help)\n");
}

sub output_ip_help
{
    print("Usage:\n".
	  "  ip bind set addr IPADDR port PORT\n".
	  "  ip bind rm {addr IPADDR | port PORT}\n".
	  "  ip bind rm addr IPADDR port PORT\n".
	  "  ip bind show [addr IPADDR | port PORT]\n");
}

sub output_version
{
    my $pname = $0;


    $pname =~ s/^.*\/([^\/]+)$/$1/o;
    print("$pname ".VERSION."\n".
	  "Copyright (C) 2014  Oleg Nemanov, Cifrabar group\n\n".
	  "This program comes with ABSOLUTELY NO WARRANTY; for details see ".
	  "LICENSE.\n".
	  "This is free software, and you are welcome to redistribute it\n".
	  "and/or modify it under the terms of the GNU GPL 3 or later; ".
	  "for details see LICENSE.\n");
}

sub do_ip_bind_show
{
    my ($args, $opts) = @_;
    my $sw;
    my $ret;
    my $data;
    my $i;


    if ( ! defined($ipaddr) ) {
	print(STDERR "An ip address must be specified\n");
	exit(1);
    }

    $ret = get_sw($ipaddr);
    $sw = $ret->{sw};
    if ( $opts->{"--verbose"} ) {
	print("Device sysDescr.0: ".$ret->{name}."\n");
    }

    $ret = $sw->ip_bind_get($args->{addr}, $args->{port});
    if ( $sw->{err}{err_code} ne "ok" ) {
	errexit(sprintf(shift(@{$sw->{err}{err_msg}}),
			@{$sw->{err}{err_msg}}), 1);
    }
    $data = [ sort { $a->{port} <=> $b->{port} } @$ret ];

    foreach $i (@$data) {
	if ( $opts->{"--save"} ) {
	    printf("$0 ip bind set addr %s port %s $ipaddr\n",
		   $i->{ip}, $i->{port});
	} else {
	    printf("%4d:  %s\n", $i->{port}, $i->{ip});
	}
    }
}

sub do_ip_bind_set
{
    my ($args, $opts) = @_;
    my $sw;
    my $ret;
    my $data;
    my $i;


    if ( ! defined($ipaddr) ) {
	print(STDERR "An ip address must be specified\n");
	exit(1);
    }

    $ret = get_sw($ipaddr);
    $sw = $ret->{sw};
    $ret = $sw->ip_bind_set($args->{addr}, $args->{port});
    if ( $sw->{err}{err_code} ne "ok" ) {
	errexit(sprintf(shift(@{$sw->{err}{err_msg}}),
			@{$sw->{err}{err_msg}}), 1);
    }
}

sub do_ip_bind_rm
{
    my ($args, $opts) = @_;
    my $sw;
    my $ret;
    my $data;
    my $i;


    if ( ! defined($ipaddr) ) {
	print(STDERR "An ip address must be specified\n");
	exit(1);
    }

    $ret = get_sw($ipaddr);
    $sw = $ret->{sw};
    $ret = $sw->ip_bind_rm($args->{addr}, $args->{port});
    if ( $sw->{err}{err_code} ne "ok" ) {
	errexit(sprintf(shift(@{$sw->{err}{err_msg}}),
			@{$sw->{err}{err_msg}}), 1);
    }
}

sub process_cmd
{
    my ($cmd, $opts) = @_;
    my @k;
    my $act;


    @k = keys(%$cmd);
    $act = $k[0];
    $acts->{$act}($cmd->{$act}, $opts);
}


######################################################################
# MAIN
######################################################################

$pcmd = parse_cmd->new(defs => $cmd_defs);
if ( $pcmd->{err}{err_code} ne "ok" ) {
    printf(STDERR shift(@{$pcmd->{err}{err_msg}}), @{$pcmd->{err}{err_msg}});
    print(STDERR "\n");
    exit(1);
}

@ARGV = $pcmd->parse(@ARGV);
if ( $pcmd->{err}{err_code} ne "ok" ) {
    printf(STDERR shift(@{$pcmd->{err}{err_msg}}), @{$pcmd->{err}{err_msg}});
    print(STDERR "\nTry help command\n");
    exit(1);
}
$ipaddr = $ARGV[0];

process_cmd($pcmd->{cmd}, $pcmd->{opts});
