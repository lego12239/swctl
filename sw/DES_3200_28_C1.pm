package sw::DES_3200_28_C1;
#
# module for dlink DES-3200-28/C1 switch
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
    $self->{_err_code_prefix} = "DES_3200_28_C1.";
    $self->{conf} = {
	objs => {
	    # Type must be IPADDRESS
	    ip => { oid => "1.3.6.1.4.1.171.12.9.3.2.1.4.3" },
	    # Type must be OCTET_STRING
	    port => { oid => "1.3.6.1.4.1.171.12.9.3.2.1.21.3",
		      # length in bytes
		      len => 8
	    },
	    # Type must be INTEGER
	    permit => { oid => "1.3.6.1.4.1.171.12.9.3.2.1.20.3",
			vals => {
			    permit => 2
			}
	    },
	    # Type must be INTEGER
	    status => { oid => "1.3.6.1.4.1.171.12.9.3.2.1.22.3",
			vals => {
			    createAndGo => 4,
			    destroy => 6
			}
	    },
	    # Type must be INTEGER
	    accessid => { oid => "1.3.6.1.4.1.171.12.9.3.2.1.2.3" },
	    # Type must be INTEGER
	    save => { oid => "1.3.6.1.4.1.171.12.1.2.18.4",
		      vals => {
			  true => 2
		      }
	    }
	}
    };
    # MODULE CONFIGURATION END

    return $self;
}

1;
