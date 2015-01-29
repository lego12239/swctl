package sw::dlink;
#
# a base module for dlink switches
#
# Copyright (C) 2014  Oleg Nemanov <lego12239@yandex.ru>, Cifrabar group
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
use Net::SNMP qw(:snmp :asn1);
use sw::_base;


our @ISA = qw(sw::_base);


#
# To add new switch:
#  1. get switch sysDescr.0
#  2. make a child object of this one with name of sysDescr.0 or a part of it
#     until a first space (with some characters replaced with _)
#  3. set in new:
#    3.1. $self->{_err_code_prefix}
#    3.2. $self->{conf}:
#      3.2.1. create an access profile entry on a switch (profile id by
#             default must be 3)
#      3.2.2. snmpwalk -c public -v 2c -m ALL -M +MIB_DIRS 192.168.208.36 1.3.6.1.4.1.171 | grep ACL
#      3.2.3. do snmptranslate for an each needed oid and fill $self->{conf}:
#        3.2.3.1. snmptranslate -Td -m ALL -M +MIB_DIRS MIB_NAME
#      3.2.4. check object types
#

sub new
{
    my $class = shift;
    my $self;


    $self = $class->SUPER::new(@_);
    return $self if ( $self->{err}{err_code} ne "ok" );

    $self->{_err_code_prefix} = "dlink.";

    return $self;
}

sub __get_objs_by_ov
{
    my $self = shift;
    my $objs;
    my $oid;
    my $value;
    my $oid_needed;
    my $ret;
    my $i;
    my $num;
    my $data = [];


    $self->_dbg("__get_objs_by_ov(".join(", ", @_)."):\n");
    $self->_dbg($_[0]);

    $objs = shift;
    $oid = shift;
    $value = shift;
    ($oid_needed) = @_;

    # Get needed object for an each object with a given value
    foreach $i (@$objs) {
	next if ( substr($i->{oid}, 0, length($oid)) ne $oid );

	if ( defined($value) ) {
	    next if ( $i->{value} ne $value );

	    if ( defined($oid_needed) ) {
		$num = $i->{oid};
		$num =~ s/^.*\.(\d+)$/$1/o;

		$ret = $self->_snmpget($oid_needed.".$num");
		return if ( $self->{err}{err_code} ne "ok" );

		if ( ! defined($ret->{oid}) ) {
		    return $self->_err("snmp_err",
				       ["Empty result to a %s request",
					$oid_needed]);
		}
		push(@$data, $ret);
	    } else {
		push(@$data, $i);
	    }
	} else {
	    push(@$data, $i);
	}

    }

    $self->_dbg("ok\n");
    $self->_err("ok");

    if ( defined($oid_needed) ) {
	return $self->__get_objs_by_ov($data, @_);
    }

    return $data;
}

sub _get_objs_by_ov
{
    my $self = shift;
    my ($oid) = @_;
    my $ret;
    my $objs;


    $self->_dbg("_get_objs_by_ov(".join(", ", @_)."):\n");

    # Get objects
    $ret = $self->_snmpwalk($oid);
    return if ( $self->{err}{err_code} ne "ok" );
    $objs = $ret;

    $ret = $self->__get_objs_by_ov($objs, @_);

    $self->_dbg($ret);
    $self->_dbg("ok\n");
    $self->_err("ok");

    return $ret;
}

sub _bitslist2port
{
    my $self = shift;
    my $i;
    my $b2n = { 128 => 1, 64 => 2, 32 => 3, 16 => 4,
		8 => 5, 4 => 6, 2 => 7, 1 => 8 };


    for($i = 0; $i <= $#_; $i++) {
	if ( $_[$i] ) {
	    if ( defined($b2n->{$_[$i]}) ) {
		return $b2n->{$_[$i]} + $i * 8;
	    }
	}
    }

    return;
}

sub _port2bitslist
{
    my $self = shift;
    my ($num) = @_;
    my $n;
    my $i;
    my $n2b = { 1 => 128, 2 => 64, 3 => 32, 4 => 16,
		5 => 8, 6 => 4, 7 => 2, 8 => 1 };
    my @ret;


    $n = int($num / 8);
    $n-- if ( ($n * 8) == $num );
    $num -= $n * 8;

    for($i = 0; $i < $n; $i++) {
	push(@ret, 0);
    }

    push(@ret, $n2b->{$num});

    return @ret;
}

sub _sw_save
{
    my $self = shift;


    $self->_snmpset($self->{conf}{objs}{save}{oid}.".0", INTEGER,
		    $self->{conf}{objs}{save}{vals}{true});
    return if ( $self->{err}{err_code} ne "ok" );

    return $self->_err("ok");
}

sub ip_bind_get
{
    my $self = shift;
    my ($ip, $port) = @_;
    my $snmp = $self->{snmp_obj};
    my $ret;
    my $ips;
    my $num;
    my $data = [];
    my $i;


    $self->_dbg("ip_bind_get(%s, %s)... ", $ip, $port);

    if ( defined($ip) && defined($port) ) {
	return $self->_err("call_err",
			   ["ip and port arguments must not be specified ".
			    "together"]);
    }

    # Get ip addresses
    $ret = $self->_snmpwalk($self->{conf}{objs}{ip}{oid});
    return if ( $self->{err}{err_code} ne "ok" );
    $ips = $ret;

    # Get ports for an each ip address
    foreach $i (@$ips) {
	if ( defined($ip) ) {
	    next if ( $i->{value} ne $ip );
	}
	$num = $i->{oid};
	$num =~ s/^.*\.(\d+)$/$1/o;

	$ret = $self->_snmpget($self->{conf}{objs}{port}{oid}.".$num");
	return if ( $self->{err}{err_code} ne "ok" );

	if ( ! defined($ret->{oid}) ) {
	    return $self->_err("snmp_err",
			       ["Empty result to a port request"]);
	}

	$num = $self->_bitslist2port(@{$ret->{value_octets}});
	if ( defined($port) ) {
	    next if ( $num ne $port );
	}
	push(@$data, { port => $num,
		       ip => $i->{value} });
    }

    $self->_dbg("ok\n");
    $self->_err("ok");

    return $data;
}

sub ip_bind_set
{
    my $self = shift;
    my ($ip, $port) = @_;
    my $snmp = $self->{snmp_obj};
    my @pbits;


    $self->_dbg("ip_bind_set(%s, %s)... ", $ip, $port);

    if (( ! defined($ip) ) || ( ! defined($port) )) {
	return $self->_err("call_err",
			   ["ip and port arguments must be specified"]);
    }

    @pbits = $self->_port2bitslist($port);
    $port = pack("W" x ($#pbits + 1), @pbits);
    $port .= "\0" x ($self->{conf}{objs}{port}{len} - $#pbits - 1);

    $self->_snmpset($self->{conf}{objs}{ip}{oid}.".0", IPADDRESS, $ip,
		    $self->{conf}{objs}{port}{oid}.".0", OCTET_STRING, $port,
		    # permit
		    $self->{conf}{objs}{permit}{oid}.".0", INTEGER,
		    $self->{conf}{objs}{permit}{vals}{permit},
		    # createAndGo
		    $self->{conf}{objs}{status}{oid}.".0", INTEGER,
		    $self->{conf}{objs}{status}{vals}{createAndGo});
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_sw_save();
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_dbg("ok\n");
    return $self->_err("ok");
}

sub ip_bind_rm
{
    my $self = shift;
    my ($ip, $port) = @_;
    my $snmp = $self->{snmp_obj};
    my @ov;
    my $value;
    my @pbits;
    my $data = [];
    my $i;


    if (( ! defined($ip)  ) && ( ! defined($port) )) {
	return $self->_err("call_err",
			   ["ip or port must be specified "]);
    }

    if ( defined($ip) ) {
	push(@ov, $self->{conf}{objs}{ip}{oid}, $ip);
    }
    if ( defined($port) ) {
	@pbits = $self->_port2bitslist($port);
	$value = pack("W" x ($#pbits + 1), @pbits);
	$value .= "\0" x ($self->{conf}{objs}{port}{len} - $#pbits - 1);
	push(@ov, $self->{conf}{objs}{port}{oid}, $value);
    }

    $data = $self->_get_objs_by_ov(@ov, $self->{conf}{objs}{accessid}{oid});
    return if ( $self->{err}{err_code} ne "ok" );

    foreach $i (@$data) {
	$self->_snmpset($self->{conf}{objs}{status}{oid}.".".$i->{value},
			INTEGER,
			$self->{conf}{objs}{status}{vals}{destroy});
	return if ( $self->{err}{err_code} ne "ok" );
    }

    $self->_sw_save();
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_err("ok");

    return $data;
}

1;
