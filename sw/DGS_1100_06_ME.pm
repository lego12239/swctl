package sw::DGS_1100_06_ME;

use strict;
use Net::SNMP;
use sw::dlink;


our @ISA = qw(sw::dlink);


sub new
{
    my $class = shift;
    my $self;


    $self = $class->SUPER::new(@_);
    return $self if ( $self->{err}{err_code} ne "ok" );

    # MODULE CONFIGURATION START
    $self->{_err_code_prefix} = "DES_1100_06_ME.";
    $self->{conf} = {
	objs => {
	    # Type must be IPADDRESS
	    ip => { oid => "1.3.6.1.4.1.171.10.134.1.1.15.3.1.1.8.3" },
	    # Type must be OCTET_STRING
	    port => { oid => "1.3.6.1.4.1.171.10.134.1.1.15.3.1.1.24.3",
		      # length in bytes
		      len => 4
	    },
	    # Type must be INTEGER
	    permit => { oid => "1.3.6.1.4.1.171.10.134.1.1.15.3.1.1.25.3",
			vals => {
			    permit => 1
			}
	    },
	    # Type must be INTEGER
	    status => { oid => "1.3.6.1.4.1.171.10.134.1.1.15.3.1.1.29.3",
			vals => {
			    active => 1,
			    createAndGo => 4,
			    createAndWait => 5,
			    destroy => 6
			}
	    },
	    # Type must be INTEGER
	    accessid => { oid => "1.3.6.1.4.1.171.10.134.1.1.15.3.1.1.1.3" },
	    # Type must be INTEGER
	    save => { oid => "1.3.6.1.4.1.171.10.134.1.1.1.10",
		      vals => {
			  true => 1
		      }
	    }
	}
    };
    # MODULE CONFIGURATION END

    return $self;
}

sub ip_bind_set
{
    my $self = shift;
    my ($ip, $port) = @_;
    my $snmp = $self->{snmp_obj};
    my @pbits;
    my $aids;
    my $id;


    $self->_dbg("ip_bind_set(%s, %s)... ", $ip, $port);

    if (( ! defined($ip) ) || ( ! defined($port) )) {
	return $self->_err("call_err",
			   ["ip and port arguments must be specified"]);
    }

    # Get a next access id
    $aids = $self->_snmpwalk($self->{conf}{objs}{accessid}{oid});
    return if ( $self->{err}{err_code} ne "ok" );
    @pbits = sort { $a->{value} cmp $b->{value} } @$aids;
    if ( @pbits ) {
        $id = $pbits[$#pbits]{value} + 1;
    } else {
        $id = 1;
    }

    @pbits = $self->_port2bitslist($port);
    $port = pack("W" x ($#pbits + 1), @pbits);
    $port .= "\0" x ($self->{conf}{objs}{port}{len} - $#pbits - 1);

    $self->_snmpset($self->{conf}{objs}{status}{oid}.".$id", INTEGER,
		    $self->{conf}{objs}{status}{vals}{createAndWait},
		    # ip and port
		    $self->{conf}{objs}{ip}{oid}.".$id", IPADDRESS, $ip,
		    $self->{conf}{objs}{port}{oid}.".$id", OCTET_STRING, $port,
		    # permit
		    $self->{conf}{objs}{permit}{oid}.".$id", INTEGER,
		    $self->{conf}{objs}{permit}{vals}{permit},
		    # status = active
		    $self->{conf}{objs}{status}{oid}.".$id", INTEGER,
		    $self->{conf}{objs}{status}{vals}{active});
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_sw_save();
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_dbg("ok\n");
    return $self->_err("ok");
}

1;
