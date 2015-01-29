package sw::_base;

use strict;
use Net::SNMP qw(:snmp :asn1);


sub new
{
    my $class = shift;
    my $self = { _err_code_prefix => "_base.",
		 err => { err_code => "ok",
			  err_msg => [] },
		 debug => 0,
		 conf => {} };


    bless($self, $class);

    $self->_get_opts(@_);
    return $self if ( $self->{err}{err_code} ne "ok" );

    return $self;
}

sub _err
{
    my $self = shift;
    my ($code, $msg) = @_;


    if (( ! defined($self->{_err_code_prefix}) ) ||
	( $code eq "ok" )) {
	$self->{err}{err_code} = $code;
    } else {
	$self->{err}{err_code} = $self->{_err_code_prefix}.$code;
    }
    if ( defined($msg) ) {
	$self->{err}{err_msg} = $msg;
    } else {
	$self->{err}{err_msg} = [];
    }

    if ( $code eq "ok" ) {
	return 1;
    } else {
	return;
    }
}

sub _dbg
{
    my $self = shift;


    return unless ( $self->{debug} );

    if ( ref($_[0]) ne "" ) {
	use Data::Dumper;
	print(Dumper($_[0]));
    } else {
	if ( $self->{debug} == 2 ) {
	    printf(STDERR @_);
	}
	printf(@_);
    }
}


sub _get_opts
{
    my $self = shift;
    my %p;


    if ( ($#_ % 2) == 0 ) {
        return $self->_err("parameters_err",
                           ["Wrong parameters format: must be a hash"]);
    }
    %p = @_;

    $self->{debug} = 1 if (( defined($p{debug}) ) && ( $p{debug} ));

    if ( ! defined($p{ipaddr}) ) {
	return $self->_err("undefined_parameter",
			   ["ipaddr parameter is undefined"]);
    }
    $self->{ipaddr} = $p{ipaddr};

    if ( ! defined($p{snmp_obj}) ) {
	if ( ! defined($p{snmp_community}) ) {
	    return $self->_err("undefined_parameter",
			       ["snmp_community parameter must be specified ".
				"if snmp_obj is undefined"]);
	}
	if ( ! defined($p{snmp_version}) ) {
	    $p{snmp_version} = "2";
	}
	$self->_snmp_connect($p{snmp_community}, $p{snmp_version});
	return if ( $self->{err}{err_code} ne "ok" );
    } else {
	$self->{snmp_obj} = $p{snmp_obj};
    }

    return $self->_err("ok");
}

sub _snmp_connect
{
    my $self = shift;
    my ($c, $v) = @_;
    my $err;


    $self->_dbg("_snmp_connect(%s, %s) to %s... ",
		$c, $v, $self->{ipaddr});

    ($self->{snmp_obj}, $err) = Net::SNMP->session(-hostname => $self->{ipaddr},
						   -community => $c,
						   -version => $v,
						   -translate => [-octetstring => 0]);
    if ( ! defined($self->{snmp_obj}) ) {
	return $self->_err("snmp_err",
			   ["Net::SNMP object creation error: %s", $err]);
    }

    $self->_dbg("ok\n");
    return $self->_err("ok");
}

sub _snmp_mk_obj
{
    my $self = shift;
    my ($oid, $type, $value) = @_;
    my $data = {};


    $data = { oid => $oid,
	      type => $type,
	      value => $value };

    if ( $type == OCTET_STRING ) {
	$data->{value_octets} = [ unpack("W".length($data->{value}),
					 $data->{value}) ];
    }

    return $data;
}

# Do snmp walk with GetNextRequest
#
# Get:
#  $_[0] - a base oid to start from
#
# Return:
#  [
#    { oid => OID1,
#      type => TYPE1,
#      value => VALUE1 },
#    ...
#  ]
#
sub _snmpwalk
{
    my $self = shift;
    my ($base_oid) = @_;
    my $snmp = $self->{snmp_obj};
    my $last_oid = $base_oid;
    my $ret;
    my @keys;
    my $data = [];


    while ( defined($ret = $snmp->get_next_request(-varbindlist => [$last_oid])) ) {
	@keys = keys(%$ret);
	if ( @keys ) {
	    if ( ! oid_base_match($base_oid, $keys[0]) ) {
		last;
	    }
	    push(@$data, $self->_snmp_mk_obj($keys[0],
					     $snmp->var_bind_types()->{$keys[0]},
					     $ret->{$keys[0]}));
	} else {
	    last;
	}
	$last_oid = $keys[0];
    }
    if ( ! defined($ret) ) {
	return $self->_err("snmp_err",
			   ["GetNextRequest error: %s", $snmp->error()]);
    }

    $self->_err("ok");

    return $data;
}

# Do snmp get with GetRequest
#
# Get:
#  $_[0] - an oid to get
#
# Return:
#  {
#    oid => OID1,
#    type => TYPE1,
#    value => VALUE1
#  }
#
sub _snmpget
{
    my $self = shift;
    my ($oid) = @_;
    my $snmp = $self->{snmp_obj};
    my @keys;
    my $ret;


    $ret = $snmp->get_request(-varbindlist => [$oid]);
    if ( ! defined($ret) ) {
	return $self->_err("snmp_err",
			   ["GetRequest error: %s", $snmp->error()]);
    }

    $self->_err("ok");

    @keys = keys(%$ret);

    return $self->_snmp_mk_obj($keys[0],
			       $snmp->var_bind_types()->{$keys[0]},
			       $ret->{$keys[0]});
}

# Do snmp set with SetRequest
#
# Get:
#  $_[0] - an oid to set
#  $_[1] - an oid type
#  $_[2] - an oid value
#  ...
#
sub _snmpset
{
    my $self = shift;
    my $snmp = $self->{snmp_obj};
    my @keys;
    my $ret;


    $ret = $snmp->set_request(-varbindlist => \@_);
    if ( ! defined($ret) ) {
	return $self->_err("snmp_err",
			   ["SetRequest error: %s", $snmp->error()]);
    }

    return $self->_err("ok");
}

1;
