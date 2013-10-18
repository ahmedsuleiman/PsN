use strict;
#---------------------------------------------------------------------
#         Perl Class Package
#---------------------------------------------------------------------
package model::problem::record::option;
use debug;


sub new {
	my $type  = shift;
	my $class = ref($type) || $type;
	my $this = ref($type) ? $type : {};
	my %parm  = @_;
	my %valid_parm = ( 'option_string' => 'SCALAR', 'name' => 'SCALAR',
			'value' => 'SCALAR' );

	if( defined $parm{'reference_object'} ){
		foreach my $possible_parm( keys %valid_parm ){
			if( not exists $parm{$possible_parm} and not exists $this -> {$possible_parm} and exists $parm{'reference_object'} -> {$possible_parm} ){
				$parm{$possible_parm} = $parm{'reference_object'} -> {$possible_parm};
			}
		}
		$parm{'reference_object'} = undef;
	}
	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in model::problem::record::option->new: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in model::problem::record::option->new: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp} or defined $this -> {$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in model::problem::record::option->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in model::problem::record::option->new: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in model::problem::record::option->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
		$this -> {$givenp} = $parm{$givenp} unless defined $this -> {$givenp};
	}


	bless $this, $class;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($this). '-> new');
# line 5 "lib/model/problem/record/option_subs.pm" 
{
	if ( defined $this->option_string ) {
	  $this -> _read_option;
	  delete $this -> {'option_string'};		# FIXME: Must be fixed with Moose
	}
}
# line 61 libgen/model/problem/record/option.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($this). '-> new');
	# End of Non-Dia code #

	return $this;
};

sub option_string {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'option_string'} = $parm;
	} else {
		return $self -> {'option_string'};
	}
}

sub name {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'name'} = $parm;
	} else {
		return $self -> {'name'};
	}
}

sub value {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'value'} = $parm;
	} else {
		return $self -> {'value'};
	}
}

sub option_count {
	my $self = shift;
	my $return_value = 0;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $return_value;
}

sub _read_option {
	my $self = shift;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> _read_option');
# line 14 "lib/model/problem/record/option_subs.pm" 
{
	#this gets strange for $PRIOR which has  NWPRI NTHETA=4,NETA=4,NTHP=4,NETP=4
	my $line = $self->option_string;
	chomp( $line );
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	my @option = split( "=", $line ); # NTHETA    4,NETA    4,NTHP   4,NETP   4
	$self->name(shift( @option ));
	$self->value(join( "=", @option )); #4,NETA=4,NTHP=4,NETP=4

}
# line 137 libgen/model/problem/record/option.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> _read_option');
	# End of Non-Dia code #

}

sub _format_option {
	my $self = shift;
	my $formatted;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> _format_option');
# line 28 "lib/model/problem/record/option_subs.pm" 
{
	$formatted = $self->name;
	if ( defined $self->value and $self->value ne '' ) {
	    $formatted = $formatted . '=' . $self->value; #NTHETA=4,NETA=4,NTHP=4,NETP=4
	}
}
# line 156 libgen/model/problem/record/option.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> _format_option');
	# End of Non-Dia code #

	return $formatted;
}

1;

