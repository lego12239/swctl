package parse_cmd;
#
# Library to parse command line parameters and options.

# Copyright (C) 2014  Oleg Nemanov <lego12239@yandex.ru>
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


# Input:
# (
#   abbrev => BOOL,
#   ignore_case => BOOL,
#   separator => REGEXP,
#   defs => {
#     opts => {
#       OPT1_NAME => {
#         type => OPT_TYPE,
#         mand => BOOL (0 by default)
#       },
#       OPT2_NAME => {
#         type => OPT_TYPE,
#         alias => ANOTHER_NAME
#       },
#       ...
#     },
#     cmds => {
#       CMD1_NAME => {},
#       CMD2_NAME => {
#         args => {
#           ARG1_NAME => {
#             type => ARG_TYPE,
#             mand => BOOL (0 by default)
#           },
#           ...
#         }
#       },
#       CMD3_NAME => {
#         mand_any => BOOL (0 by default)
#         args => {
#           ARG1_NAME => {
#             type => ARG_TYPE,
#           },
#           ...
#         }
#       },
#       ...
#     }
#   }
# )
#
# Where:
#  BOOL: 0|1
#  OPT_TYPE: bool|inc|str|num|int|stra|numa|inta|strlN|numlN|intlN
#  ARG_TYPE: bool|inc|str|num|int|stra|numa|inta|strlN|numlN|intlN
#    Where:
#      N - a number starting from 2
#
sub new
{
    my $class = shift;
    my $self = { _err_code_prefix => "parse_opts.",
		 _conf => { abbrev => 1,
			    ignore_case => 0,
			    separator => '/',
			    use_first_match => 0,
			    ignore_wrong_option => 0 },
		 _defs => {},
		 _args => [],
		 opts => {},
		 cmd => {},
		 err => { err_code => "ok",
			  err_msg => [] } };


    bless($self, $class);

    $self->_get_conf(@_);
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

sub _is_in_array
{
    my $self = shift;
    my ($val, $a) = @_;
    my $i;


    foreach $i (@$a) {
	return 1 if ( $i eq $val);
    }

    return 0;
}

sub _add_opts
{
    my $self = shift;
    my ($opt_aliases, $opts) = @_;
    my $i;
    my @keys;


    @keys = keys(%$opt_aliases);
    foreach $i (@keys) {
	if ( ! defined($opts->{$i}) ) {
	    $opts->{$i} = $opt_aliases->{$i};
	} else {
	    return $self->_err("parameters_err",
			       ["Option %s error: option with such a name ".
				"already exist", $i]);
	}
    }

    return $self->_err("ok");
}

sub _get_opt_
{
    my $self = shift;
    my ($opt) = @_;
    my $data = {};
    my $i;


    if ( ! defined($opt->{name}) ) {
	return $self->_err("call_err",
			   ["%s error: can't find %s parameter",
			    "_get_opt", "name"]);
    }
    $data->{$opt->{name}}{name} = $opt->{name};

    if ( ! $self->_is_in_array($opt->{type},
			       ["bool", "inc", "str", "num", "int",
				"stra", "numa", "inta"]) ) {
	return $self->_err("parameters_err",
			   ["Option %s error: wrong type %s",
			    $opt->{name}, $opt->{type}]);
    }
    $data->{$opt->{name}}{type} = $opt->{type};

    if ( defined($opt->{mand}) && ( $opt->{mand} )) {
	$data->{$opt->{name}}{mand} = 1;
    } else {
	$data->{$opt->{name}}{mand} = 0;
    }

    if ( defined($opt->{abbrev}) ) {
	if ( $opt->{abbrev} ) {
	    $data->{$opt->{name}}{abbrev} = 1;
	} else {
	    $data->{$opt->{name}}{abbrev} = 0;
	}
    } else {
	$data->{$opt->{name}}{abbrev} = $self->{_conf}{abbrev};
    }

    if ( defined($opt->{alias}) ) {
	$data->{$opt->{alias}} = $data->{$opt->{name}};
    }

    $self->_err("ok");

    return $data;
}

sub _get_opt
{
    my $self = shift;
    my ($opt, $oname) = @_;
    my $data = {};
    my $i;


    if ( ! defined($oname) ) {
	return $self->_err("call_err",
			   ["%s error: can't find %s parameter",
			    "_get_opt", "oname"]);
    }
    $data->{$oname}{name} = $oname;

    if ( ! $self->_is_in_array($opt->{type},
			       ["bool", "inc", "str", "num", "int",
				"stra", "numa", "inta"]) ) {
	return $self->_err("parameters_err",
			   ["Option %s error: wrong type %s",
			    $oname, $opt->{type}]);
    }
    $data->{$oname}{type} = $opt->{type};

    if ( defined($opt->{alias}) ) {
	$data->{$opt->{alias}} = $data->{$oname};
    }

    $self->_err("ok");

    return $data;
}

sub _get_opts
{
    my $self = shift;
    my ($opts) = @_;
    my @keys;
    my $k;
    my $opt_aliases;
    my $data = {};


    @keys = keys(%$opts);
    foreach $k (@keys) {
	if ( defined($opts->{$k}{type}) ) {
	    if ( $self->{_conf}{ignore_case} ) {
		$opt_aliases = $self->_get_opt($opts->{$k}, lc($k));
	    } else {
		$opt_aliases = $self->_get_opt($opts->{$k}, $k);
	    }
	    return if ( $self->{err}{err_code} ne "ok" );

	    $self->_add_opts($opt_aliases, $data);
	    return if ( $self->{err}{err_code} ne "ok" );
	} else {
	    return $self->_err("parameters_err",
			       ["Option %s error: ".
				"type is not set", $k]);
	}
    }

    $self->_err("ok");

    return $data;
}

sub _get_arg
{
    my $self = shift;
    my ($arg, $aname) = @_;
    my $data = {};
    my $i;


    if ( ! defined($aname) ) {
	return $self->_err("call_err",
			   ["%s error: can't find %s parameter",
			    "_get_arg", "aname"]);
    }
    $data->{name} = $aname;

    if ( ! $self->_is_in_array($arg->{type},
			       ["bool", "inc", "str", "num", "int",
				"stra", "numa", "inta"]) ) {
	return $self->_err("parameters_err",
			   ["Argument %s error: wrong type %s",
			    $aname, $arg->{type}]);
    }
    $data->{type} = $arg->{type};

    if ( defined($arg->{mand})  && ( $arg->{mand} )) {
	$data->{mand} = 1;
    } else {
	$data->{mand} = 0;
    }

    $self->_err("ok");

    return $data;
}

sub _get_args
{
    my $self = shift;
    my ($args) = @_;
    my @keys;
    my $k;
    my $arg;
    my $data = {};


    @keys = keys(%$args);
    foreach $k (@keys) {
	if ( defined($args->{$k}{type}) ) {
	    if ( $self->{_conf}{ignore_case} ) {
		$data->{lc($k)} = $self->_get_arg($args->{$k}, lc($k));
	    } else {
		$data->{$k} = $self->_get_arg($args->{$k}, $k);
	    }
	    return if ( $self->{err}{err_code} ne "ok" );
	} else {
	    return $self->_err("parameters_err",
			       ["Argument %s error: ".
				"type is not set", $k]);
	}
    }

    $self->_err("ok");

    return $data;
}

sub _add_cmd
{
    my $self = shift;
    my ($cmd, $cname, $cmds) = @_;
    my @a;
    my $i;


    if ( ! defined($cname) ) {
	return $self->_err("call_err",
			   ["%s error: can't find %s parameter",
			    "_get_cmd", "cname"]);
    }

    @a = split($self->{_conf}{separator}, $cname);
    foreach $i (@a) {
	if ( ! defined($cmds->{$i}) ) {
	    $cmds->{$i} = {};
	}
	$cmds = $cmds->{$i};
    }
    
    $cmds->{name} = $cname;

    if ( defined($cmd->{mand_any}) && ( $cmd->{mand_any} )) {
	$cmds->{mand_any} = 1;
    } else {
	$cmds->{mand_any} = 0;
    }

    $cmds->{args} = {};
    if ( defined($cmd->{args}) ) {
	@a = keys(%{$cmd->{args}});
	foreach $i (@a) {
	    $cmds->{args} = $self->_get_args($cmd->{args});
	    return if ( $self->{err}{err_code} ne "ok" );
	}
    }
    
    $self->_err("ok");

    return $data;
}

sub _get_cmds
{
    my $self = shift;
    my ($cmds) = @_;
    my @keys;
    my $k;
    my $cmd;
    my $data = {};

    @keys = keys(%$cmds);
    foreach $k (@keys) {
	if ( $self->{_conf}{ignore_case} ) {
	    $cmd = $self->_add_cmd($cmds->{$k}, lc($k), $data);
	} else {
	    $cmd = $self->_add_cmd($cmds->{$k}, $k, $data);
	}
	return if ( $self->{err}{err_code} ne "ok" );
    }

    $self->_err("ok");

    return $data;
}

sub _get_defs
{
    my $self = shift;
    my ($defs, $gname) = @_;
    my @keys;
    my ($k, $oname);
    my $opt_aliases;
    my $data = {};


    if ( defined($defs->{opts}) ) {
	$data->{opts} = $self->_get_opts($defs->{opts});
	return if ( $self->{err}{err_code} ne "ok" );
    }

    if ( defined($defs->{cmds}) ) {
	$data->{cmds} = $self->_get_cmds($defs->{cmds});
	return if ( $self->{err}{err_code} ne "ok" );
    }

    $self->_err("ok");

    return $data;
}

sub _get_conf
{
    my $self = shift;
    my %p;


    if ( ($#_ % 2) == 0 ) {
	return $self->_err("parameters_err",
			   ["Wrong parameters format: must be a hash"]);
    }
    %p = @_;

    if ( defined($p{abbrev}) && ( $p{abbrev} )) {
	$self->{_conf}{abbrev} = 1;
    }
    if ( defined($p{ignore_case}) && ( $p{ignore_case} )) {
	$self->{_conf}{ignore_case} = 1;
    }
    if ( defined($p{separator}) ) {
	$self->{_conf}{separator} = $p{separator};
    }
    if ( defined($p{ignore_wrong_option}) ) {
	$self->{_conf}{ignore_wrong_option} = $p{ignore_wrong_option};
    }

    if ( defined($p{defs}) ) {
	$self->{_defs} = $self->_get_defs($p{defs}, undef);
	return if ( $self->{err}{err_code} ne "ok" );
    }

    return $self->_err("ok");
}

# Parse an option
# Get:
#  $_[0] - a definition of an option to parse
#  $_[1] - arguments list
#  $_[2] - a previous value of an option if exist
#
# Return:
#  an option value
#
sub _parse_opt
{
    my $self = shift;
    my ($opt_def, $args, $opt) = @_;
    my $val;


    $self->_err("ok");

    if ( $opt_def->{type} eq "bool" ) {
	return 1;
    } elsif ( $opt_def->{type} eq "inc" ) {
	if ( defined($opt) ) {
	    return $opt + 1;
	} else {
	    return 1;
	}
    } elsif ( $opt_def->{type} eq "str" ) {
	$val = shift(@$args);
	if ( ! defined($val) ) {
	    return $self->_err("args_err",
			       ["%s option parameter must be a string",
				$opt_def->{name}]);
	}
	return $val;
    } elsif ( $opt_def->{type} eq "num" ) {
	$val = shift(@$args);
	if ( $val !~ /^\d+(?:\.\d+)?$/o ) {
	    return $self->_err("args_err",
			       ["%s option parameter must be a number",
				$opt_def->{name}]);
	}
	return $val;
    } elsif ( $opt_def->{type} eq "int" ) {
	$val = shift(@$args);
	if ( $val !~ /^\d+$/o ) {
	    return $self->_err("args_err",
			       ["%s option parameter must be an integer",
				$opt_def->{name}]);
	}
	return $val;
    }

    return $self->_err("opt_type_err",
		       ["Can't process %s option type %s",
			$opt_def->{name}, $opt_def->{type}]);
}

# Parse a command argument
# Get:
#  $_[0] - a definition of an argument to parse
#  $_[1] - arguments list
#  $_[2] - a previous value of an argument if exist
#  $_[3] - a command name (only for err_msg constructing)
#
# Return:
#  an argument value
#
sub _parse_arg
{
    my $self = shift;
    my ($arg_def, $args, $arg, $cname) = @_;
    my $val;


    $self->_err("ok");

    if ( $arg_def->{type} eq "bool" ) {
	return 1;
    } elsif ( $arg_def->{type} eq "inc" ) {
	if ( defined($arg) ) {
	    return $arg + 1;
	} else {
	    return 1;
	}
    } elsif ( $arg_def->{type} eq "str" ) {
	$val = shift(@$args);
	if ( ! defined($val) ) {
	    return $self->_err("args_err",
			       ["'%s' command '%s' argument parameter ".
				"must be a string",
				join(" ", split($self->{_conf}{separator}, $cname)),
				$arg_def->{name}]);
	}
	return $val;
    } elsif ( $arg_def->{type} eq "num" ) {
	$val = shift(@$args);
	if ( $val !~ /^\d+(?:\.\d+)?$/o ) {
	    return $self->_err("args_err",
			       ["'%s' command '%s' argument parameter ".
				"must be a number",
				join(" ", split($self->{_conf}{separator}, $cname)),
				$arg_def->{name}]);
	}
	return $val;
    } elsif ( $arg_def->{type} eq "int" ) {
	$val = shift(@$args);
	if ( $val !~ /^\d+$/o ) {
	    return $self->_err("args_err",
			       ["'%s' command '%s' argument parameter ".
				"must be an integer",
				join(" ", split($self->{_conf}{separator}, $cname)),
				$arg_def->{name}]);
	}
	return $val;
    }

    return $self->_err("arg_type_err",
		       ["Can't process '%s' command '%s' argument type %s",
			join(" ", split($self->{_conf}{separator}, $cname)),
			$arg_def->{name}, $arg_def->{type}]);
}

# Check existence of all mandatory arguments of a command
#
# Get:
#  $_[0] - a command definition
#  $_[1] - arguments
#
# Return:
#  1 if all mandatory arguments exist, or undef otherwise (set $self->{err}).
#
sub _check_cmd_args
{
    my $self = shift;
    my ($cmd_def, $args) = @_;
    my @keys;
    my $i;
    my $any_set = 0;


    @keys = keys(%{$cmd_def->{args}});
    foreach $i (@keys) {
	if ( defined($args->{$i}) ) {
	    $any_set = 1;
	} else {
	    if ( $cmd_def->{args}{$i}{mand} ) {
		return $self->_err("args_err",
				   ["Mandatory '%s' argument of '%s' command ".
				    "is not supplied",
				    $i,
				    join(" ", split($self->{_conf}{separator},
						    $cmd_def->{name})) ]);
	    }
	}
    }

    if (( $cmd_def->{mand_any} ) && ( ! $any_set )) {
	return $self->_err("args_err",
			   ["Specify more arguments for '%s' command",
			    join(" ", split($self->{_conf}{separator},
					    $cmd_def->{name})) ]);
    }

    return $self->_err("ok");
}

# Parse a command
# Get:
#  $_[0] - a definition of a command to parse
#  $_[1] - arguments list
#
# Return:
#  a command value
#
sub _parse_cmd
{
    my $self = shift;
    my ($cmd_def, $args) = @_;
    my $arg;
    my $name;
    my $data = {};
    my $cdata;


    $data->{$cmd_def->{name}} = {};
    $cdata = $data->{$cmd_def->{name}};

    if ( defined($cmd_def->{args}) ) {
	while ( $#$args >= 0 ) {
	    $arg = shift(@$args);

	    if ( defined($cmd_def->{args}{$arg}) ) {
		$name = $cmd_def->{args}{$arg}{name};
		$cdata->{$name} = $self->_parse_arg($cmd_def->{args}{$arg},
						    $args,
						    $cdata->{$name},
						    $cmd_def->{name});
		return if ( $self->{err}{err_code} ne "ok" );
	    } else {
		# End of options list
		unshift(@$args, $arg);
		last;
	    }
	    
	}
    }

    $self->_check_cmd_args($cmd_def, $cdata);
    return if ( $self->{err}{err_code} ne "ok" );

    $self->_err("ok");

    return $data;
}

# Find a command by a name.
#
# Get:
#  $_[0] - a command name
#  $_[1] - commands definition
#
# Return:
#  a command ref or undef (if not found)
#
sub _find_cmd
{
    my $self = shift;
    my ($cname, $cmds) = @_;
    my @keys;
    my @matched;
    my $i;


    $self->_err("ok");

    if ( $self->{_conf}{ignore_case} ) {
	$cname = lc($cname);
    }

    if ( ! $self->{_conf}{abbrev} ) {
	return $cmds->{$cname};
    }

    # if we use abbreviations
    @keys = sort(keys(%$cmds));
    foreach $i (@keys) {
	if ( substr($i, 0, length($cname)) eq $cname ) {
	    if ( $self->{_conf}{use_first_match} ) {
		return $cmds->{$i};
	    }
	    push(@matched, $i);
	}
    }

    if ( $#matched == 0 ) {
	return $cmds->{$matched[0]};
    } elsif ( $#matched > 0 ) {
	return $self->_err("args_err",
			   ["Ambiguous command '%s' match: %s",
			   $cname, join(", ", @matched)]);
    }

    return;
}

sub _parse
{
    my $self = shift;
    my ($args, $defs) = @_;
    my $data = { opts => {},
		 cmd => {} };
    my $cmds;
    my $cmd;
    my $name;
    my $arg;


    # Parse options
    if ( defined($defs->{opts}) ) {
	while ( $#$args >= 0 ) {
	    $arg = shift(@$args);

	    if ( defined($defs->{opts}{$arg}) ) {
		$name = $defs->{opts}{$arg}{name};
		$data->{opts}{$name} = $self->_parse_opt($defs->{opts}{$arg},
							 $args,
							 $data->{opts}{$name});
		return if ( $self->{err}{err_code} ne "ok" );
	    } else {
		# End of options list
		unshift(@$args, $arg);
		last;
	    }
	}
    }

    $self->_err("ok");

    # Parse a command
    $cmds = $defs->{cmds};
    if ( defined($defs->{cmds}) ) {
	while ( $#$args >= 0 ) {
	    $arg = shift(@$args);
	    if ( ! $self->{_conf}{ignore_wrong_option} ) {
		if ( $arg eq "--" ) {
		    $self->{_conf}{ignore_wrong_option} = 1;
		    next;
		}
		if ( substr($arg, 0, 1) eq "-" ) {
		    return $self->_err("args_err",
				       ["You can't use %s here", $arg]);
		}
	    }
	    $cmd = $self->_find_cmd($arg, $cmds);
	    return if ( $self->{err}{err_code} ne "ok" );

	    if ( defined($cmd) ) {
		if ( defined($cmd->{name}) &&
		     ( ref($cmd->{name}) eq "" )) {
		    $data->{cmd} = $self->_parse_cmd($cmd, $args);
		    return if ( $self->{err}{err_code} ne "ok" );
		    return $data;		    
		}
		$cmds = $cmd;
	    } else {
		return $self->_err("args_err",
				   ["Unknown command"]);
	    }
	}
    }
 
    return $self->_err("args_err",
		       ["Command is incomplete"]);
}

sub parse
{
    my $self = shift;
    my $data;


    $self->{_args} = [@_];
    $data = $self->_parse($self->{_args}, $self->{_defs});
    return if ( $self->{err}{err_code} ne "ok" );

    $self->{opts} = $data->{opts};
    $self->{cmd} = $data->{cmd};

    return @{$self->{_args}};
}

1;
