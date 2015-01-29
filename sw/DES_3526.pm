package sw::DES_3526;

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
    $self->{_err_code_prefix} = "DES_3526.";
    $self->{conf} = {
	objs => {
	    # Type must be IPADDRESS
	    ip => { oid => "1.3.6.1.4.1.171.12.9.2.2.1.4.3" },
	    # Type must be OCTET_STRING
	    port => { oid => "1.3.6.1.4.1.171.12.9.2.2.1.21.3",
		      # length in bytes
		      len => 4
	    },
	    # Type must be INTEGER
	    permit => { oid => "1.3.6.1.4.1.171.12.9.2.2.1.20.3",
			vals => {
			    permit => 2
			}
	    },
	    # Type must be INTEGER
	    status => { oid => "1.3.6.1.4.1.171.12.9.2.2.1.22.3",
			vals => {
			    createAndGo => 4,
			    destroy => 6
			}
	    },
	    # Type must be INTEGER
	    accessid => { oid => "1.3.6.1.4.1.171.12.9.2.2.1.2.3" },
	    # Type must be INTEGER
	    save => { oid => "1.3.6.1.4.1.171.12.1.2.6",
		      vals => {
			  true => 3
		      }
	    }
	}
    };
    # MODULE CONFIGURATION END

    return $self;
}

1;
