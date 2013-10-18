use strict;
#---------------------------------------------------------------------
#         Perl Class Package
#---------------------------------------------------------------------
package tool::gls;
use Carp;
use tool::modelfit;
use Math::Random;
use Data::Dumper;
use Config;
use debug;


#---------------------------------------------------------------------
#         Inherited Class Packages
#---------------------------------------------------------------------
use base qw(tool);

sub new {
	my $type  = shift;
	my $class = ref($type) || $type;
	my %superParms;
	my $this = ref($type) ? $type : {};
	my %parm  = @_;
	my %valid_parm = ( 'samples' => 'SCALAR', 'gls_model' => 'SCALAR',
			'set_simest' => 'SCALAR', 'ind_shrinkage' => 'SCALAR',
			'additional_callback' => 'SCALAR', 'sim_table' => 'SCALAR',
			'reminimize' => 'SCALAR', 'iwres_shrinkage' => 'SCALAR',
			'additive_theta' => 'SCALAR', 'have_nwpri' => 'SCALAR',
			'have_tnpri' => 'SCALAR', 'probnum' => 'SCALAR',
			'logfile' => 'REF', 'results_file' => 'SCALAR' );

	if( defined $parm{'reference_object'} ){
		foreach my $possible_parm( keys %valid_parm ){
			if( not exists $parm{$possible_parm} and not exists $this -> {$possible_parm} and exists $parm{'reference_object'} -> {$possible_parm} ){
				$parm{$possible_parm} = $parm{'reference_object'} -> {$possible_parm};
			}
		}
	}
	foreach my $givenp ( keys %parm ) {
		$superParms{$givenp} = $parm{$givenp} and next unless( defined $valid_parm{$givenp});

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->new: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp} or defined $this -> {$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->new: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
		$this -> {$givenp} = $parm{$givenp} unless defined $this -> {$givenp};
	}

	$this -> {'gls_model'} = defined $parm{'gls_model'} ? $parm{'gls_model'} : 0 unless defined $this -> {'gls_model'};
	$this -> {'set_simest'} = defined $parm{'set_simest'} ? $parm{'set_simest'} : 0 unless defined $this -> {'set_simest'};
	$this -> {'ind_shrinkage'} = defined $parm{'ind_shrinkage'} ? $parm{'ind_shrinkage'} : 0 unless defined $this -> {'ind_shrinkage'};
	$this -> {'additional_callback'} = defined $parm{'additional_callback'} ? $parm{'additional_callback'} : 0 unless defined $this -> {'additional_callback'};
	$this -> {'sim_table'} = defined $parm{'sim_table'} ? $parm{'sim_table'} : 0 unless defined $this -> {'sim_table'};
	$this -> {'reminimize'} = defined $parm{'reminimize'} ? $parm{'reminimize'} : 0 unless defined $this -> {'reminimize'};
	$this -> {'have_nwpri'} = defined $parm{'have_nwpri'} ? $parm{'have_nwpri'} : 0 unless defined $this -> {'have_nwpri'};
	$this -> {'have_tnpri'} = defined $parm{'have_tnpri'} ? $parm{'have_tnpri'} : 0 unless defined $this -> {'have_tnpri'};
	$this -> {'probnum'} = defined $parm{'probnum'} ? $parm{'probnum'} : 1 unless defined $this -> {'probnum'};
	$this -> {'logfile'} = defined $parm{'logfile'} ? $parm{'logfile'} : ['gls.log'] unless defined $this -> {'logfile'};
	$this -> {'results_file'} = defined $parm{'results_file'} ? $parm{'results_file'} : 'gls_results.csv' unless defined $this -> {'results_file'};

	bless $this, $class;
	tool::new($this,%superParms);

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($this). '-> new');
# line 16 "lib/tool/gls_subs.pm" 
for my $accessor ('logfile','raw_results_file','raw_nonp_file'){
    my @new_files=();
    my @old_files = @{$this->$accessor};
    for (my $i=0; $i < scalar(@old_files); $i++){
	my $name;
	my $ldir;
	( $ldir, $name ) =
	    OSspecific::absolute_path( $this ->directory(), $old_files[$i] );
	push(@new_files,$ldir.$name) ;
    }
    $this->$accessor(\@new_files);
}	


foreach my $model ( @{$this -> models} ) {
  foreach my $problem (@{$model->problems()}){
    if (defined $problem->nwpri_ntheta()){
      ui -> print( category => 'all',
		   message => "Warning: gls does not support \$PRIOR NWPRI.",
		   newline => 1);
      last;
    }
  }
}

if ( scalar (@{$this -> models->[0]-> problems}) > 2 ){
  croak('Cannot have more than two $PROB in the input model.');
}elsif  (scalar (@{$this -> models->[0]-> problems}) == 2 ){
  if ((defined $this -> models->[0]-> problems->[0]->priors()) and 
      scalar(@{$this -> models->[0]-> problems->[0] -> priors()})>0 ){
    my $tnpri=0;
    foreach my $rec (@{$this -> models->[0]-> problems->[0] -> priors()}){
      unless ((defined $rec) &&( defined $rec -> options )){
	carp("No options for rec \$PRIOR" );
      }
      foreach my $option ( @{$rec -> options} ) {
	if ((defined $option) and 
	    (($option->name eq 'TNPRI') || (index('TNPRI',$option ->name ) == 0))){
	  $tnpri=1;
	}
      }
    }

    $this->have_tnpri(1) if ($tnpri);
  }
  if ($this->have_tnpri()){
    unless( defined $this -> models->[0]-> extra_files ){
      croak('When using $PRIOR TNPRI you must set option -extra_files to '.
		     'the msf-file, otherwise the msf-file will not be copied to the NONMEM '.
		     'run directory.');
    }

  }else{
    croak('The input model must contain exactly one problem, unless'.
	' first $PROB has $PRIOR TNPRI');
  }
  my $est_record = $this->models->[0] -> record( problem_number => (1+$this->have_tnpri()),
						     record_name => 'estimation' );
  unless (defined $est_record and scalar(@{$est_record})>0){
    croak('Input model must have an estimation record');
  }

}

# line 145 libgen/tool/gls.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($this). '-> new');
	# End of Non-Dia code #

	return $this;
};

sub samples {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'samples'} = $parm;
	} else {
		return $self -> {'samples'};
	}
}

sub gls_model {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'gls_model'} = $parm;
	} else {
		return $self -> {'gls_model'};
	}
}

sub set_simest {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'set_simest'} = $parm;
	} else {
		return $self -> {'set_simest'};
	}
}

sub ind_shrinkage {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'ind_shrinkage'} = $parm;
	} else {
		return $self -> {'ind_shrinkage'};
	}
}

sub additional_callback {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'additional_callback'} = $parm;
	} else {
		return $self -> {'additional_callback'};
	}
}

sub sim_table {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'sim_table'} = $parm;
	} else {
		return $self -> {'sim_table'};
	}
}

sub reminimize {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'reminimize'} = $parm;
	} else {
		return $self -> {'reminimize'};
	}
}

sub iwres_shrinkage {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'iwres_shrinkage'} = $parm;
	} else {
		return $self -> {'iwres_shrinkage'};
	}
}

sub additive_theta {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'additive_theta'} = $parm;
	} else {
		return $self -> {'additive_theta'};
	}
}

sub have_nwpri {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'have_nwpri'} = $parm;
	} else {
		return $self -> {'have_nwpri'};
	}
}

sub have_tnpri {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'have_tnpri'} = $parm;
	} else {
		return $self -> {'have_tnpri'};
	}
}

sub probnum {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'probnum'} = $parm;
	} else {
		return $self -> {'probnum'};
	}
}

sub logfile {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'logfile'} = $parm;
	} else {
		return $self -> {'logfile'};
	}
}

sub results_file {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'results_file'} = $parm;
	} else {
		return $self -> {'results_file'};
	}
}

sub modelfit_setup {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'model_number' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->modelfit_setup: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->modelfit_setup: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->modelfit_setup: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->modelfit_setup: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->modelfit_setup: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my $model_number = $parm{'model_number'};

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> modelfit_setup');
# line 87 "lib/tool/gls_subs.pm" 
{ 
  my $model = $self -> models -> [$model_number-1];
  my ( @seed, $new_datas, $skip_ids, $skip_keys, $skip_values );
  my @orig_and_sim_models;
  my $orig_model;
  my $sim_model;
  my @msfo_stems_original;

  $self->probnum(2) if ($self->have_tnpri());

  my @table_header;
  my @all_iwres_files;
  my @orig_table_names;

  my $gls_model;
  my $newthetanum=$model->nthetas(problem_number => $self->probnum())+1;
  my $sim_record;
  my $simdirname='simulation_dir'; 
  my $shrinkage_value;
  $self->additional_callback(0);


  my $gls_estimation_string ='';
  my $sim_simulation_string ='';
  my $sim_estimation_string ='';
  if ($self->set_simest()){
    my @gls_lines;
    my @sim_lines;

    open(MOD, $self-> models->[0]->full_name()) || 
	die("Couldn't open ".$self-> models->[0]->full_name()." : $!");

    while(<MOD>) {
      if (s/^\s*\;+\s*(gls-|Gls-|GLS-)//){
	#removed first part
	my $lead=$1;
	if (s/^(sim|Sim|SIM)\s+;*\s*//){
	  push(@sim_lines,$_);
	}elsif(s/^(final|Final|FINAL)\s+;*\s*//){
	  push(@gls_lines,$_);
	}else{
	  ui->print(message => "Warning: Tag on line ".$lead.$_." not recognized, ignored",
		    newline=> 1);
	}
      }
    }
    close(MOD);

    if (scalar(@gls_lines)>0){
      unless ($gls_lines[0] =~ /^\$EST[A-Z]*/){
	croak("First line of tagged gls-final is ".$gls_lines[0]." which ".
		   "is not recognized as a \$EST record.");
      }
      $gls_lines[0] =~ s/^\$EST[A-Z]*//;
      foreach my $line (@gls_lines){
	if ($line =~ /^\$/){
	  croak("Error: More than one line found starting with \n".
		     ";gls-final \$<something>\n".
		     "gls program cannot handle multiple NONMEM ".
		     "records with tag ;gls-final");
	}
	chomp $line;
	$gls_estimation_string .= ' '.$line; 
      }
    }
    if (scalar(@sim_lines)>0){
      unless ($sim_lines[0] =~ /^\$[A-Z]+/){
	croak("First line of tagged gls-sim is ".$sim_lines[0]." which ".
		   "is not recognized as a \$ NONMEM record.");
	
      }
      my $is_est=0;
      my $is_sim=0;
      foreach my $line (@sim_lines){
	if ($line =~ /^\$/){
	  $line =~ s/^\$([A-Z]*)//;
	  my $record = $1;
	  if ($record =~ /^SIM/){
	    croak("Cannot have more than one \$SIM record ".
		       "in combination with tag ;gls-sim")
		if ($is_sim > 0);
	    $is_sim=1;
	    $is_est = 2 if ($is_est == 1); #stop storing est if did before
	  }elsif ($record =~ /^EST/){
	    croak("Cannot have more than one \$EST record ".
		       "in combination with tag ;gls-sim")
		if ($is_est > 0);
	    $is_est=1;
	    $is_sim = 2 if ($is_sim == 1); #stop storing sim if did before.
	  }else{
	    croak("Cannot have \$"."$record in combination with tag ;gls-sim");
	  }
	}
	chomp $line;
	$sim_estimation_string .= ' '.$line if ($is_est == 1); 
	if ($is_sim == 1){
	  #remove NSUBS setting, if any
	  $line =~ s/SUBP[A-Z]*=[0-9]+//;
	  $line =~ s/NSUB[A-Z]*=[0-9]+//;
	  $line =~ s/TRUE=[A-Z]+//;
	  $sim_simulation_string .= ' '.$line ; 
	}

      }
    }

  }


  if ($self->gls_model()){
    $gls_model = $model ->
	copy( filename    => $self -> directory.'m'.$model_number.'/gls.mod',
	      target      => 'disk',
	      copy_data   => 1,
	      copy_output => 0);
    $gls_model -> outputs -> [0] -> directory($self -> directory.'m'.$model_number);

    $gls_model -> drop_dropped unless $gls_model->skip_data_parsing();
    $gls_model -> remove_option( record_name  => 'estimation',
				 option_name  => 'MSFO',
				 fuzzy_match => 1,
				 problem_numbers => [($self->probnum())],
				 record_number => 0); #0 means all

    if (defined $self->additive_theta()){
      
      $gls_model -> initial_values( parameter_numbers => [[$newthetanum]],
				    new_values        => [[$self->additive_theta()]],
				    add_if_absent     => 1,
				    parameter_type    => 'theta',
				    problem_numbers   => [$self->probnum()]);
      $gls_model -> labels( parameter_type    => 'theta',
			    parameter_numbers => [[$newthetanum]],
			    problem_numbers   => [$self->probnum()],
			    new_values        => [["$newthetanum add_err"]] );
      $gls_model->fixed(parameter_type => 'theta',
			parameter_numbers => [[$newthetanum]],
			new_values => [[1]] );
      
    }
    if (defined $gls_model ->outputs() and 
	defined $gls_model->outputs()->[0] and
	$gls_model->outputs()->[0]-> have_output()){
      $gls_model -> update_inits ( from_output => $gls_model->outputs()->[0],
				    problem_number => $self->probnum());
    }

    unless ($gls_model->skip_data_parsing()){
      $gls_model -> drop_dropped;
    }
    
  }else{
    #no gls_model
    $orig_model = $model ->
	copy( filename    => $self -> directory.'m'.$model_number.'/original.mod',
	      target      => 'disk',
	      copy_data   => 1,
	      copy_output => 0);
    $orig_model -> outputs -> [0] -> directory($self -> directory.'m'.$model_number);
    
    $orig_model -> drop_dropped unless $orig_model->skip_data_parsing();
    
    
    if ($self->ind_shrinkage()){

      #create sim record if not present
      $sim_record = $orig_model -> record( problem_number => $self->probnum(),
					   record_name => 'simulation' );
      if( scalar(@{$sim_record}) > 0 ){
	$sim_record = $sim_record->[0];
#	print $sim_record->[0]."\n";
	foreach my $altopt ('SUBPROBLEMS','SUBPROBS','NSUBPROBLEMS','NSUBPROBS','NSUBS'){
	  #NONMEM accepts a heck of a lot of alternatives...
#	  $sim_record->[0] -> remove_option( name => $altopt,
#					     fuzzy_match => 1 );
	  $orig_model -> remove_option(record_name => 'simulation',
				       option_name => $altopt,
				       fuzzy_match => 1,
				       problem_numbers => [$self->probnum()]);
	  
	}
	if ($self->have_nwpri() or $self->have_tnpri()){
	  $orig_model -> remove_option(record_name => 'simulation',
				       option_name => 'TRUE',
				       fuzzy_match => 1,
				       problem_numbers => [$self->probnum()]);

	}
      }else{
	# set $SIMULATION record
	my @arr=('(000 NEW)');
	$sim_record = \@arr;#dummy seed
      }
      if (length($sim_simulation_string)> 0){
	my @arr=($sim_simulation_string);
	$sim_record = \@arr;
      }
      $sim_record->[0] .= ' SUBPROB=1';
      
      if ($self->have_nwpri() or $self->have_tnpri()){
	$sim_record->[0] .= ' TRUE=PRIOR';
      }
    } #end if ind_shrinkage
#    $orig_model -> remove_records( type => 'simulation' ); #No, sometimes want both sim and est
    
    $orig_model -> remove_option( record_name  => 'estimation',
				  option_name  => 'MSFO',
				  fuzzy_match => 1,
				  problem_numbers => [($self->probnum())],
				  record_number => 0); #0 means all
	
    if (defined $self->additive_theta()){
      $orig_model -> initial_values( parameter_numbers => [[$newthetanum]],
				     new_values        => [[$self->additive_theta()]],
				     add_if_absent     => 1,
				     parameter_type    => 'theta',
				     problem_numbers   => [$self->probnum()]);
      $orig_model -> labels( parameter_type    => 'theta',
			     parameter_numbers => [[$newthetanum]],
			     problem_numbers   => [$self->probnum()],
			     new_values        => [['additive_error']] );
      $orig_model->fixed(parameter_type => 'theta',
			 parameter_numbers => [[$newthetanum]],
			 new_values => [[1]] );
      
      
    }
    
    $gls_model = $orig_model ->
	copy( filename    => $self -> directory.'m'.$model_number.'/gls.mod',
	      target      => 'disk',
	      copy_data   => 0,
	      copy_output => 0);
    $gls_model -> outputs -> [0] -> directory($self -> directory.'m'.$model_number);
    $gls_model -> remove_records( type => 'simulation' );
    if (length($gls_estimation_string)>1){
      $gls_model -> set_records (type => 'estimation',
				 record_strings => [$gls_estimation_string],
				 problem_numbers => [($self->probnum())]);
    }
    #only allow PLEV if simulating
    if ($self->have_tnpri() or $self->have_nwpri()){
      $gls_model -> remove_option( record_name  => 'prior',
				   problem_numbers => [(1)],
				   option_name  => 'PLEV',
				   fuzzy_match => 1);
    }

    $orig_model -> shrinkage_stats( enabled => 1 );
# unless 
#	(defined $self->iwres_shrinkage() or $self->ind_shrinkage());
        
    $orig_model -> remove_records( type => 'covariance' );

    # set $TABLE record
    
    my $oprob = $orig_model -> problems -> [$self->probnum()-1];
    if( defined $oprob -> inputs and defined $oprob -> inputs -> [0] -> options ) {
      foreach my $option ( @{$oprob -> inputs -> [0] -> options} ) {
	push( @table_header, $option -> name ) unless 
	    (($option -> value eq 'DROP' or $option -> value eq 'SKIP'
	      or $option -> name eq 'DROP' or $option -> name eq 'SKIP'));
      }
    } else {
      croak("Trying to construct table for simulation".
		    " but no headers were found in \$model_number-INPUT" );
    }
    #never IWRES in orig model, only in sims
    $oprob -> add_records( type           => 'table',
			   record_strings => [ join( ' ', @table_header ).
					       ' IPRED PRED NOPRINT NOAPPEND ONEHEADER FILE=glsinput.dta']);
    
    my $orig_model_output;
    if (defined $model ->outputs() and 
	defined $model->outputs()->[0] and
	$model->outputs()->[0]-> have_output()
	and $self->ind_shrinkage()){
      #we do not need to run original before sims, because already have final ests
      $orig_model_output = $model->outputs()->[0];
      $orig_model -> update_inits ( from_output => $orig_model_output,
				    problem_number => $self->probnum(),
				    ignore_missing_parameters => 1);
      $orig_model -> _write( write_data => 1 );
      push( @orig_and_sim_models, $orig_model );
      $simdirname='orig_and_simulation_dir'; 
    }else{
      $orig_model -> _write( write_data => 1 );
      #run original here to get param estimates for sim
      my $run_orig = tool::modelfit -> new( 
	%{common_options::restore_options(@common_options::tool_options)},
	top_tool         => 0,
	models           => [$orig_model],
	base_directory   => $self -> directory,
	directory        => $self -> directory.'original_dir'.$model_number, 
	parent_tool_id   => $self -> tool_id,
	logfile	         => undef,
	raw_results_file     => [$self ->raw_results_file()->[$model_number-1]],
	prepared_models       => undef,
#	shrinkage => ((defined $self->iwres_shrinkage() or $self->ind_shrinkage)? 0 : 1),
	shrinkage => 1,
	_raw_results_callback => $self ->
	_modelfit_raw_results_callback( model_number => $model_number ),
	data_path =>'../../m'.$model_number.'/',
	abort_on_fail => $self->abort_on_fail);
      
      ui -> print( category => 'gls',
		   message  => "Running original model" );

      $run_orig -> run;
      $self->additional_callback(1);

      unless (defined $run_orig -> raw_results){
	croak("Running original model failed. Check output in ".$run_orig->directory());
      }
      unless (defined $self->iwres_shrinkage() or $self->ind_shrinkage){
	my $cols = scalar @{$run_orig -> raw_results -> [0]}; # first non-header row
	my $line_structure = $run_orig->raw_line_structure;
	my ($start,$len) = split(',',$run_orig->raw_line_structure->{'1'}->{'shrinkage_iwres'});
	croak("undef shrinkage_iwres") unless (defined $start);
	$shrinkage_value = ($run_orig -> raw_results -> [0][$start])/100; #value is in percent
      }
    
      if (defined $orig_model ->outputs() and 
	  defined $orig_model->outputs()->[0] and
	  $orig_model->outputs()->[0]-> have_output()){
	$orig_model_output = $orig_model->outputs()->[0];
	$orig_model -> update_inits ( from_output => $orig_model_output,
				      problem_number => $self->probnum());
      }
    }

    if (defined $orig_model_output){
      $gls_model -> update_inits ( from_output => $orig_model_output,
				   problem_number => $self->probnum());
    }

    #change table FILE in gls if table present. Left original model as is.
    my $tbl_nm_ref = 
	$gls_model -> get_option_value( record_name  => 'table',
					option_name  => 'FILE',
					record_index => 'all',
					problem_index => ($self->probnum()-1));
    
    if( defined $tbl_nm_ref ){
      for (my $k=0; $k<scalar(@{$tbl_nm_ref}); $k++){
	if (defined $tbl_nm_ref->[$k]){
	  my $name = $tbl_nm_ref->[$k];
	  $name =~ s/[0-9]*$//;
	  $gls_model -> remove_option( record_name  => 'table',
				       option_name  => 'FILE',
				       fuzzy_match => 1,
				       record_number => ($k+1));
	  
	  $gls_model -> add_option(record_name  => 'table',
				   record_number  => ($k+1),
				   option_name  => 'FILE',
				   problem_numbers => [($self->probnum())],
				   option_value => $name.'-gls' );   
	}
      }
    }

    #ignore @ since simdata contains header rows. can skip old ignores since filtered
    #set for all $PROB
    $gls_model -> set_option( record_name  => 'data',
			      option_name  => 'IGNORE',
			      option_value => '@',
			      fuzzy_match => 1);

    foreach my $modprob (@{$gls_model->problems()}){
      my $inp_ref =  $modprob -> inputs();
      if ( defined $inp_ref and defined $inp_ref -> [0] ) {
	my $input = $inp_ref -> [0];
	my $opt_ref = $input -> options;
	if ( defined $opt_ref ) {
	  my @options = @{$opt_ref};
	  my @keep;
	  foreach my $option ( @options ) {
	    push ( @keep, $option ) if ( not ($option -> value eq 'DROP' or $option -> value eq 'SKIP'
					      or $option -> name eq 'DROP' or $option -> name eq 'SKIP'));
	  }
	  $input -> options( \@keep );
	  $input -> _add_option( option_string => 'PIPR' );
	  $input -> _add_option( option_string => 'PPRE' );
	  if ($self->ind_shrinkage()){
	    $input -> _add_option( option_string => 'ISHR' );
	  }
	}
      }
    }

 
  }  #done if not gls_model    
      
#	my $method = $gls_model -> get_option_value( record_name  => 'estimation',
#						      problem_index => ($self->probnum()-1),
#						      option_name  => 'METHOD');
#	if ((not defined $method) or ($method eq '0') or ($method =~ /^[ZHISBC]/)){
#	  $gls_model -> set_option( record_name  => 'estimation',
#				     option_name  => 'METHOD',
#				     option_value => 'COND',
#				     fuzzy_match => 1);  
#	}
#  if( $gls_model -> is_option_set( record => 'estimation', 
#				   name => 'INTERACTION',
#				   fuzzy_match => 1) ){
#    $gls_model -> remove_option( record_name  => 'estimation',
#				 problem_numbers => [($self->probnum())],
#				 option_name  => 'INTERACTION',
#				 fuzzy_match => 1);
#  }
  $gls_model -> add_option( record_name  => 'data',
			    problem_numbers => [($self->probnum())],
			    option_name  => 'IGNORE',
			    option_value => '(PIPR.LE.0.000000001)');
  
  
  

  

  my $samples=0;
  $samples = $self -> samples() if ($self->ind_shrinkage() and not $self->gls_model());
  
  for( my $sim_no = 1; $sim_no <= $samples ; $sim_no++ ) {
      
    my $sim_name = "simulation-$sim_no.mod";
    my $sim_out = "simulation-$sim_no.lst";

    if( $sim_no == 1 ) {
      $sim_model = $orig_model->
	  copy( filename    => $self -> directory.'m'.$model_number.'/'.$sim_name,
		target      => 'disk',
		copy_data   => 0,
		copy_output => 0);
      $sim_model -> remove_records( type => 'table' );
      $sim_model -> remove_records( type => 'covariance' );
      $sim_model -> shrinkage_stats( enabled => 1 );

      #set IGNORE=@ since datafile will
      #get a header during copying. Keep IGNORE=LIST
      my $sim_ignorelist = $orig_model -> get_option_value( record_name  => 'data',
							    problem_index => ($self->probnum()-1),
							    option_name  => 'IGNORE',
							    option_index => 'all');
      $sim_model -> remove_option( record_name  => 'data',
				   problem_numbers => [($self->probnum())],
				   option_name  => 'IGNORE',
				   fuzzy_match => 1);
	
      if ((defined $sim_ignorelist) and scalar (@{$sim_ignorelist})>0){
	foreach my $val (@{$sim_ignorelist}){
	  unless (length($val)==1){
	    #unless single character ignore, cannot keep that since need @
	    $sim_model -> add_option( record_name  => 'data',
				      problem_numbers => [($self->probnum())],
				      option_name  => 'IGNORE',
				      option_value => $val);
	  }
	}
      }
      $sim_model -> add_option( record_name  => 'data',
				 problem_numbers => [($self->probnum())],
				 option_name  => 'IGNORE',
				 option_value => '@');
      

      # set $TABLE record
      
      $sim_model -> add_records( type           => 'table',
				 problem_numbers => [($self->probnum())],
				 record_strings => ['IWRES ID NOPRINT NOAPPEND ONEHEADER FILE=dummy']);

      if ($self->sim_table()){
	$sim_model -> add_records( type           => 'table',
				   problem_numbers => [($self->probnum())],
				   record_strings => ['ID TIME IPRED W IWRES NOPRINT ONEHEADER FILE=dummy2']);
      }

      if (length($sim_estimation_string)>1){
	$sim_model -> set_records (type => 'estimation',
				   record_strings => [$sim_estimation_string],
				   problem_numbers => [($self->probnum())]);
      }else{
	unless ($self->reminimize()){
	  $sim_model -> set_maxeval_zero(print_warning => 1,
					 last_est_complete => $self->last_est_complete(),
					 niter_eonly => $self->niter_eonly(),
					 need_ofv => 1);
	}
      }
      

    }else{
      $sim_model = $orig_and_sim_models[$#orig_and_sim_models]->
	  copy( filename    => $self -> directory.'m'.$model_number.'/'.$sim_name,
		target      => 'disk',
		copy_data   => 0,
		copy_output => 0);

    }#end if elsesim_no==1
    $sim_model -> ignore_missing_files( 1 );
    $sim_model -> outputfile( $self -> directory.'m'.$model_number.'/'.$sim_out );
    $sim_model -> ignore_missing_files( 0 );
    my $prob = $sim_model -> problems -> [$self->probnum()-1];

    my @new_record;
    foreach my $sline ( @{$sim_record } ){
      my $new_line;
      my $sim_line = $sline;
      while( $sim_line =~ /([^()]*)(\([^()]+\))(.*)/g ){
	my $head = $1;
	my $old_seed = $2;
	$sim_line = $3;
	$new_line .= $head;
	
	while( $old_seed =~ /(\D*)(\d+)(.*)/ ){
	  $new_line .= $1;
	  $new_line .= random_uniform_integer( 1, 0, 1000000 ); # Upper limit is from nmhelp 
	  $old_seed = $3;
	}
	
	$new_line .= $old_seed;
	
      }
      push( @new_record, $new_line.$sim_line );
    }
    
    $prob -> set_records( type => 'simulation',
			  record_strings => \@new_record );


    if( $sim_model -> is_option_set( record => 'simulation', 
				     name => 'ONLYSIMULATION',
				     fuzzy_match => 1) ){
      $sim_model -> remove_records( type => 'estimation' );
    }

    my $iwres_file = "iwres-$sim_no.dta";
    $prob -> remove_option( record_name  => 'table',
			    option_name  => 'FILE',
			    fuzzy_match => 1,
			    record_number => 1);
      
    $prob -> add_option(record_name  => 'table',
			record_number  => 1,
			option_name  => 'FILE',
			option_value => $iwres_file );   
    
    if ($self->sim_table()){
      my $tab_file = "sdtab-sim$sim_no.dta";
      $prob -> remove_option( record_name  => 'table',
			      option_name  => 'FILE',
			      fuzzy_match => 1,
			      record_number => 2);
      
      $prob -> add_option(record_name  => 'table',
			  record_number  => 2,
			  option_name  => 'FILE',
			  option_value => $tab_file );   
    }

    push( @all_iwres_files, $self -> directory.'m'.$model_number.'/'.
	  $iwres_file );


    $sim_model -> _write( write_data => 0 );
    push( @orig_and_sim_models, $sim_model );


    if( $sim_no == $samples ) {
      my $run_sim = tool::modelfit -> new( 
	%{common_options::restore_options(@common_options::tool_options)},
	top_tool         => 0,
	models           => \@orig_and_sim_models,
	base_directory   => $self -> directory,
	directory        => $self -> directory.$simdirname.$model_number, 
	parent_tool_id   => $self -> tool_id,
	logfile	         => undef,
	raw_results_file     => [$self ->raw_results_file()->[$model_number-1]], #change??
	prepared_models       => undef,
	shrinkage => 1,
	_raw_results_callback => $self ->
	_modelfit_raw_results_callback( model_number => $model_number ),
	data_path =>'../../m'.$model_number.'/',
	abort_on_fail => $self->abort_on_fail);

      ui -> print( category => 'gls',
		   message  => "Running simulations to compute shrinkage" );

      $run_sim -> run;
      $self->additional_callback(2);

      unless (defined $run_sim -> raw_results){
	croak("Running simulations failed. Check output in ".$run_sim->directory());
      }
      my @matrix;
      my @sums;
      my $nsim=0;
      my $append_header;
      foreach my $file (@all_iwres_files){
	#need not do filtering, as long as can handle strange values for nonobs
	#must keep same number of rows in shrinkage col
	open( IWR, $file ) or croak("Could not find $file.");
	$nsim++;
	my $index = 0;
	while (my $row = <IWR>){
	  chomp $row;
	  next if ($row =~ /TABLE NO/);
	  if ($row =~ /IWRE/){
	    $append_header = $row."\n";
	    next;
	  }
	  #order is IWRES ID ...
	  $row =~ s/^\s*//;
	  my ($iwres,$rest)=split(/\s+/,$row,2);
#	  print "iwr $iwres rest $rest\n";
	  if ($nsim>1){
	    push(@{$matrix[$index]},$iwres);
	    $sums[$index] += $iwres;
	  }else{
	    $matrix[$index]=[$iwres];
	    $sums[$index]=$iwres;
	  }
	  $index++;
	}
	close(IWR);
#	die;
      }
      my @shrinkage_arr = (' ',' ');
      for (my $i=0;$i<scalar(@sums);$i++){
	my $mean=$sums[$i]/$nsim;
	my $sum_errors_pow2=0;
	foreach my $val (@{$matrix[$i]}){
	  $sum_errors_pow2 = $sum_errors_pow2+($val - $mean)**2;
	}
	my $stdev=0;
	unless( $sum_errors_pow2 <= 0 ){
	  $stdev= sqrt ($sum_errors_pow2/($nsim-1));
	}
	push(@shrinkage_arr,sprintf("%.8f",(1-$stdev)));
      }
      #append to glsinput.dta, also print to own file
      my $fname = 'm'.$model_number.'/glsinput.dta'; 
      if (-e $fname){
	my @tmp = OSspecific::slurp_file($fname);
	my $first=1;
	open(GLS, ">$fname") || die("Couldn't open $fname : $!");
	open(DAT, ">ind_iwres_shrinkage.dta") || 
	    die("Couldn't open ind_iwres_shrinkage.dta : $!");
	print GLS join(' ',@table_header);
	print GLS " PIPR PPRE ISHR\n";
	print DAT "ISHR\n";
	for (my $i=2; $i<scalar(@tmp); $i++){
	  chomp $tmp[$i];
	  print GLS $tmp[$i]." ".$shrinkage_arr[$i]."\n";
	  print DAT $shrinkage_arr[$i]."\n";
	}
	close (GLS);
	close (DAT);
      }else{
	die "$fname does not exist\n";
      }

    }

  } #end loop over number of simulations

  $gls_model -> set_file( record => 'data',
			  new_name => 'm1/glsinput.dta', #add path
			  problem_number => 0) unless ($self->gls_model()); #0 means all
  
  $gls_model -> shrinkage_stats( enabled => 1 );

  my $shrinkage;
  if (defined $self->iwres_shrinkage()){
    $shrinkage = $self->iwres_shrinkage();
  }elsif (not $self->ind_shrinkage()){
    $shrinkage = $shrinkage_value;
    $shrinkage = sprintf("%.8f",$shrinkage);
  }else{
    $shrinkage = 'ISHR'; 
  }
  my @newcode = ("SHRI=$shrinkage\n",
		 "IF(SHRI.LE.0) SHRI = 0\n");
  push(@newcode,"GLSP = SHRI*PPRE + (1-SHRI)*PIPR\n");

  #change W, set GLSP here
  #can look for ADVAN<any number> this way
  my ($advan,$junk) = $gls_model->problems->[0] -> _option_val_pos( record_name => 'subroutine',
								    name => 'ADVAN',
								    exact_match => 0);
  my $have_advan = scalar(@{$advan}) > 0;
  
  my @code;
  my $use_pred=0;
  if( $have_advan ){
    # We have an ADVAN option in $SUBROUTINE, get $ERROR code
    @code = @{$gls_model -> error( problem_number => 1 )};
  }
  unless ($have_advan and ( $#code > 0 )) {
    @code = @{$gls_model -> pred( problem_number => 1 )};
    $use_pred = 1;
  }
  
  my $found_W;
  my $i = 0;
  for ( @code ) {
    if ( /^\s*W\s*=/) {
      if ( /^\s*W\s*=\s*SQRT\(/ and /IPRED/) {
	$found_W = $i;
	s/IPRED/GLSP/;
	if (defined $self->additive_theta){
	  my $newexp = "=SQRT(THETA($newthetanum)**2+";
	  s/=\s*SQRT\(/$newexp/;
	}

	#keep looking, may be more than one W definition line
      }else{
	croak("W definition does not match the pattern W = SQRT(...IPRED...)");
      }
    }
    push(@newcode,$_);
    $i++;
  }
  unless ( defined $found_W ) {
    croak("Could not determine a good place to add the GLS code,\n".
		  " i.e. no W= line was found\n" );
  }
    
  if ( $use_pred ) {
    $gls_model -> pred( problem_number => 1,
			     new_pred       => \@newcode );
  } else {
    $gls_model -> pk( problem_number => 1,
		      new_error         => \@newcode );
  }
  
  $gls_model -> _write;
  $gls_model -> flush_data();

  my $subdir = 'modelfit';

  my @subtools = ();
  @subtools = @{$self -> subtools} if (defined $self->subtools);
  shift( @subtools );
  my %subargs = ();
  if ( defined $self -> subtool_arguments ) {
    %subargs = %{$self -> subtool_arguments};
  }
  if (1){
      $subargs{'data_path'}='../../m'.$model_number.'/';
  }

  $self->stop_motion_call(tool=>'gls',message => "Preparing to run gls model ")
      if ($self->stop_motion());
  $self->tools([]) unless (defined $self->tools);
  push( @{$self -> tools},
	tool::modelfit -> new(
	  %{common_options::restore_options(@common_options::tool_options)},
	  top_tool         => 0,
	  logfile	         => undef,
	  raw_results_file     => [$self ->raw_results_file()->[0]],
#	  raw_results      => undef,
	  prepared_models  => undef,
	  rerun => 1,
	  models         => [$gls_model],
	  base_directory => $self -> directory.'/m'.$model_number.'/',
	  directory      => $self -> directory.'/'.$subdir.'_dir'.$model_number,
	  subtools       => $#subtools >= 0 ? \@subtools : undef,
	  shrinkage      => 1,
	  data_path =>'../../m'.$model_number.'/',
	  _raw_results_callback => $self ->
	  _modelfit_raw_results_callback( model_number => $model_number ),
	  %subargs ) );

  ui -> print( category => 'gls',
	       message  => "\nRunning gls model" );

}
# line 1160 libgen/tool/gls.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> modelfit_setup');
	# End of Non-Dia code #

}

sub _modelfit_raw_results_callback {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'model_number' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->_modelfit_raw_results_callback: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->_modelfit_raw_results_callback: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->_modelfit_raw_results_callback: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->_modelfit_raw_results_callback: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->_modelfit_raw_results_callback: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my $model_number = $parm{'model_number'};
	my $subroutine;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> _modelfit_raw_results_callback');
# line 889 "lib/tool/gls_subs.pm" 

# Use the mc's raw_results file.
my ($dir,$file) = 
    OSspecific::absolute_path( $self -> directory,
			       $self -> raw_results_file->[$model_number-1] );
my ($npdir,$npfile) = 
    OSspecific::absolute_path( $self -> directory,
			       $self -> raw_nonp_file->[$model_number-1]);


#my $orig_mod = $self -> models->[$model_number-1];
$subroutine = sub {
  #can have 2 $PROB if tnpri and est_sim, interesting with 2nd $PROB only
  my $modelfit = shift;
  my $mh_ref   = shift;
  my %max_hash = %{$mh_ref};
  $modelfit -> raw_results_file( [$dir.$file] );
  $modelfit -> raw_nonp_file( [$npdir.$npfile] );
  $modelfit -> raw_results_append( 1 ) if ($self->additional_callback > 0);
  my $totsamples=1;
  $totsamples = $self -> samples() if (defined $self -> samples());


  # a column with run type, original or gls or sim is prepended. 

  #if prior tnpri nothing will be in raw_results for first $PROB, can
  #take first row for model as final estimates as usual, even if
  #it happens to be from second $PROB

  if ( defined $modelfit -> raw_results() ) {
    $self->stop_motion_call(tool=>'gls',message => "Preparing to rearrange raw_results in memory, adding ".
			    "model name information")
	if ($self->stop_motion());
    
    my $n_rows = scalar(@{$modelfit -> raw_results()});

    my $last_model= 0;
    my $sample = 0; 

    if ($self->additional_callback < 1){
#      print "first call\n";
      unshift( @{$modelfit -> raw_results_header}, 'run_type' );
#      if (defined $self->iwres_shrinkage()){
#	push( @{$modelfit -> raw_results_header}, 'input_shrinkage' );
#      }
    }

    my $type;
    if (($self->additional_callback < 1) and (not $self->gls_model()) ){
      $type='original';
    }elsif ($self->additional_callback == 1 and $self->ind_shrinkage()){
      #never run orig model if gls_model
      $type='simulation';
    }else{
      $type='gls';
    }
    for (my $i=0; $i< $n_rows; $i++){
      my $this_model = $modelfit -> raw_results()->[$i]->[0]; 
      my $step= ($this_model-$last_model);
      if ($last_model > 0 and $step>0){
	$type='simulation';
      }
      if ($step < 0){
	ui -> print( category => 'gls',
		     message  => "Warning: It seems the raw_results is not sorted");
      }else {
#	if (defined $self->iwres_shrinkage()){
#	  push( @{$modelfit -> raw_results()->[$i]}, $self->iwres_shrinkage() );
#	}
	$sample += $step; #normally +1, sometimes 0,sometimes 2 or more
	unshift( @{$modelfit -> raw_results()->[$i]}, $type );

#	if ($sample <= $totsamples and (not $self->gls_model())){
#	  unshift( @{$modelfit -> raw_results()->[$i]}, 'original' );
#	}else{
#	  unshift( @{$modelfit -> raw_results()->[$i]}, 'gls' );
#	}
      }
      $last_model=$this_model;
    }

    if ($self->additional_callback < 1){
      $self->raw_line_structure($modelfit -> raw_line_structure);

      my $laststart=0;
      foreach my $mod (sort({$a <=> $b} keys %{$self->raw_line_structure})){
	foreach my $category (keys %{$self->raw_line_structure -> {$mod}}){
	  next if ($category eq 'line_numbers');
	  my ($start,$len) = split(',',$self->raw_line_structure -> {$mod}->{$category});
	  $self->raw_line_structure -> {$mod}->{$category} = ($start+1).','.$len; #add 1 for hypothesis
	  $laststart=($start+$len) if (($start+$len)> $laststart);
	}
	$self->raw_line_structure -> {$mod}->{'run_type'} = '0,1';
#	$self->raw_line_structure -> {$mod}->{'input_shrinkage'} = $laststart.',1';
      }

      $self->raw_line_structure -> write( $dir.'raw_results_structure' );
    }
  } #end if defined modelfit->raw_results

  if ( defined $modelfit -> raw_nonp_results() ) {
    
    my $n_rows = scalar(@{$modelfit -> raw_nonp_results()});

    my $last_model= 0;
    my $sample = 0; 
    my $type;
    if (($self->additional_callback < 1) and (not $self->gls_model()) ){
      $type='original';
    }elsif ($self->additional_callback == 1){
      $type='simulation';
    }else{
      $type='gls';
    }

    unshift( @{$modelfit -> raw_nonp_results_header}, 'run_type' );
#    if (defined $self->iwres_shrinkage()){
#      push( @{$modelfit -> raw_nonp_results_header}, 'input_shrinkage' );
#    }

    
    for (my $i=0; $i< $n_rows; $i++){
      my $this_model = $modelfit -> raw_nonp_results()->[$i]->[0]; 
      my $step= ($this_model-$last_model);
      if ($last_model > 0 and $step>0){
	$type='simulation';
      }
      if ($step < 0){
	ui -> print( category => 'gls',
		     message  => "Warning: It seems the raw_nonp_results is not sorted");
      }else {
#	if (defined $self->iwres_shrinkage()){
#	  push( @{$modelfit -> raw_nonp_results()->[$i]}, $self->iwres_shrinkage() );
#	}
	$sample += $step; #normally +1, sometimes 0,sometimes 2 or more
	unshift( @{$modelfit -> raw_nonp_results()->[$i]}, $type );

      }
      $last_model=$this_model;
    }

  } #end if defined modelfit->raw_nonp_results


  $self -> raw_results_header(\@{$modelfit -> raw_results_header});
  $self -> raw_nonp_results_header(\@{$modelfit -> raw_nonp_results_header});
  #  New header
  
};
return $subroutine;

# line 1350 libgen/tool/gls.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> _modelfit_raw_results_callback');
	# End of Non-Dia code #

	return \&subroutine;
}

sub modelfit_analyze {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'model_number' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->modelfit_analyze: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->modelfit_analyze: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->modelfit_analyze: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->modelfit_analyze: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->modelfit_analyze: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my $model_number = $parm{'model_number'};

	# Start of Non-Dia code #
	# End of Non-Dia code #

}

sub prepare_results {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( '' => '' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->prepare_results: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->prepare_results: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->prepare_results: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->prepare_results: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->prepare_results: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}


	# Start of Non-Dia code #
	# End of Non-Dia code #

}

sub rmse_percent {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'use_runs' => 'm_ARRAY', 'column_index' => 'm_SCALAR',
			'start_row_index' => 'SCALAR', 'end_row_index' => 'SCALAR',
			'initial_value' => 'm_SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->rmse_percent: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->rmse_percent: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->rmse_percent: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->rmse_percent: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->rmse_percent: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my @use_runs = defined $parm{'use_runs'} ? @{$parm{'use_runs'}} : ();
	my $column_index = $parm{'column_index'};
	my $start_row_index = defined $parm{'start_row_index'} ? $parm{'start_row_index'} : 0;
	my $end_row_index = $parm{'end_row_index'};
	my $initial_value = $parm{'initial_value'};
	my $rmse_percent;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $rmse_percent;
}

sub bias_percent {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'use_runs' => 'm_ARRAY', 'column_index' => 'm_SCALAR',
			'start_row_index' => 'SCALAR', 'end_row_index' => 'SCALAR',
			'initial_value' => 'm_SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->bias_percent: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->bias_percent: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->bias_percent: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->bias_percent: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->bias_percent: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my @use_runs = defined $parm{'use_runs'} ? @{$parm{'use_runs'}} : ();
	my $column_index = $parm{'column_index'};
	my $start_row_index = defined $parm{'start_row_index'} ? $parm{'start_row_index'} : 0;
	my $end_row_index = $parm{'end_row_index'};
	my $initial_value = $parm{'initial_value'};
	my $bias_percent;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $bias_percent;
}

sub median {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'use_runs' => 'm_ARRAY', 'column_index' => 'm_SCALAR',
			'start_row_index' => 'SCALAR', 'end_row_index' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->median: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->median: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->median: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->median: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->median: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my @use_runs = defined $parm{'use_runs'} ? @{$parm{'use_runs'}} : ();
	my $column_index = $parm{'column_index'};
	my $start_row_index = defined $parm{'start_row_index'} ? $parm{'start_row_index'} : 0;
	my $end_row_index = $parm{'end_row_index'};
	my $median;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $median;
}

sub skewness_and_kurtosis {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'use_runs' => 'm_ARRAY', 'column_index' => 'm_SCALAR',
			'start_row_index' => 'SCALAR', 'end_row_index' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->skewness_and_kurtosis: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->skewness_and_kurtosis: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->skewness_and_kurtosis: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->skewness_and_kurtosis: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->skewness_and_kurtosis: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my @use_runs = defined $parm{'use_runs'} ? @{$parm{'use_runs'}} : ();
	my $column_index = $parm{'column_index'};
	my $start_row_index = defined $parm{'start_row_index'} ? $parm{'start_row_index'} : 0;
	my $end_row_index = $parm{'end_row_index'};
	my $skewness;
	my $kurtosis;
	my $mean;
	my $stdev;
	my $warn = 0;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $skewness ,$kurtosis ,$mean ,$stdev ,$warn;
}

sub max_and_min {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'use_runs' => 'm_ARRAY', 'column_index' => 'm_SCALAR',
			'start_row_index' => 'SCALAR', 'end_row_index' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->max_and_min: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->max_and_min: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->max_and_min: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->max_and_min: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->max_and_min: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my @use_runs = defined $parm{'use_runs'} ? @{$parm{'use_runs'}} : ();
	my $column_index = $parm{'column_index'};
	my $start_row_index = defined $parm{'start_row_index'} ? $parm{'start_row_index'} : 0;
	my $end_row_index = $parm{'end_row_index'};
	my $maximum;
	my $minimum;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	return $maximum ,$minimum;
}

sub cleanup {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( '' => '' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in tool::gls->cleanup: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in tool::gls->cleanup: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in tool::gls->cleanup: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->cleanup: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in tool::gls->cleanup: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}


	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> cleanup');
# line 872 "lib/tool/gls_subs.pm" 
{
  #remove tablefiles in simulation NM_runs, they are 
  #copied to m1 by modelfit and read from there anyway.
  for (my $samp=1;$samp<=$self->samples(); $samp++){
    unlink $self -> directory."/simulation_dir1/NM_run".$samp."/mc-sim-".$samp.".dat";
    unlink $self -> directory."/simulation_dir1/NM_run".$samp."/mc-sim-".$samp."-1.dat"; #retry
  }

}
# line 1673 libgen/tool/gls.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> cleanup');
	# End of Non-Dia code #

}

1;

