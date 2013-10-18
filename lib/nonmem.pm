use strict;
#---------------------------------------------------------------------
#         Perl Class Package
#---------------------------------------------------------------------
package nonmem;
if( $0 =~ /nonmem.pm$/ ) {
  use FindBin qw($Bin);
  use lib "$Bin";
}
use Carp;
use File::Copy 'cp';
use Config;
use Cwd;
if( $0 =~ /nonmem.pm$/ ) {
	require PsN;
	my $version = $ARGV[3];
	my $compile = $ARGV[4];
	my $execute = $ARGV[5];

	PsN::set_nonmem_info($version); #version

	my $nonmem = nonmem -> new( modelfile       => $ARGV[0],
								outputfile      => $ARGV[1],
								nice            => $ARGV[2], 
								version         => $version,
								display_iterations => $ARGV[6], 
								nonmem_options => $ARGV[7], 
								parafile        => $ARGV[8], 
								nodes           => $ARGV[9], 
								fsubs           => [split( /,/ , $ARGV[10] )],
								nmqual            => $execute == 3 ? 1:0,
								show_version    => 0);

	if( $execute == 2){ #run nmfe
		unless ($nonmem -> run_with_nmfe())
		{
			carp($nonmem -> error_message );
		}
		#more checking here?
	}elsif( $execute == 3){ #run nmqualscript
		unless ($nonmem -> run_with_nmqual())
		{
			carp($nonmem -> error_message );
		}
	} else {
		my $mess = "PsN can only be run if option -nmfe or -run_on_sge_nmfe is set.\n".
			" Separate compiling and running is not supported.";
		$nonmem->store_message(message => $mess);
		carp($mess );
	}
}
use debug;


sub new {
	my $type  = shift;
	my $class = ref($type) || $type;
	my $this = ref($type) ? $type : {};
	my %parm  = @_;
	my %valid_parm = ( 'error_message' => 'SCALAR', 'fsubs' => 'ARRAY',
			'display_iterations' => 'SCALAR', 'full_path_executable' => 'SCALAR',
			'nmqual' => 'SCALAR', 'nm_directory' => 'SCALAR',
			'nm_minor_version' => 'SCALAR', 'nm_major_version' => 'SCALAR',
			'parafile' => 'SCALAR', 'nodes' => 'SCALAR',
			'nonmem_options' => 'SCALAR', 'modelfile' => 'm_SCALAR',
			'nice' => 'SCALAR', 'nmtran_message' => '',
			'outputfile' => 'SCALAR', 'version' => 'SCALAR',
			'show_version' => 'SCALAR', 'adaptive' => 'SCALAR' );

	if( defined $parm{'reference_object'} ){
		foreach my $possible_parm( keys %valid_parm ){
			if( not exists $parm{$possible_parm} and not exists $this -> {$possible_parm} and exists $parm{'reference_object'} -> {$possible_parm} ){
				$parm{$possible_parm} = $parm{'reference_object'} -> {$possible_parm};
			}
		}
		$parm{'reference_object'} = undef;
	}
	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in nonmem->new: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in nonmem->new: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp} or defined $this -> {$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in nonmem->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in nonmem->new: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in nonmem->new: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
		$this -> {$givenp} = $parm{$givenp} unless defined $this -> {$givenp};
	}

	$this -> {'display_iterations'} = defined $parm{'display_iterations'} ? $parm{'display_iterations'} : 0 unless defined $this -> {'display_iterations'};
	$this -> {'nmqual'} = defined $parm{'nmqual'} ? $parm{'nmqual'} : 0 unless defined $this -> {'nmqual'};
	$this -> {'nodes'} = defined $parm{'nodes'} ? $parm{'nodes'} : 0 unless defined $this -> {'nodes'};
	$this -> {'nice'} = defined $parm{'nice'} ? $parm{'nice'} : 19 unless defined $this -> {'nice'};
	$this -> {'version'} = defined $parm{'version'} ? $parm{'version'} : 5 unless defined $this -> {'version'};
	$this -> {'show_version'} = defined $parm{'show_version'} ? $parm{'show_version'} : 1 unless defined $this -> {'show_version'};
	$this -> {'adaptive'} = defined $parm{'adaptive'} ? $parm{'adaptive'} : 0 unless defined $this -> {'adaptive'};

	bless $this, $class;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($this). '-> new');
# line 58 "lib/nonmem_subs.pm" 
{
	unless( defined $this -> outputfile ){
		my $tmp = $this -> modelfile;
		$tmp =~ s/\.mod$/\.lst/;
		$this -> outputfile($tmp);
	}
	my @check_paths=('/run/','/util/','/');

	my $confignmdir = $PsN::nmdir;
	unless( defined $confignmdir ){
		my $mess = "Unknown NONMEM version ".$this -> version." specified.\n";
		$this->store_message('message' =>$mess);
		print $mess;
	}
	$this -> nm_directory($confignmdir);
	$this -> nm_major_version($PsN::nm_major_version);
	$this -> nm_minor_version($PsN::nm_minor_version);
	my $found_nonmem =0;
	unless (defined $this -> nm_major_version){
		my $mess;
		open( FH, "<", 'psn_nonmem_error_messages.txt' );
		while( <FH> ){
			chomp;
			$mess .= " ".$_."\n";
		}
		close( FH );
		$this -> error_message($mess);
		return 0;
	}

	if ($this -> nm_major_version == 7){
		if (not defined $this -> nm_minor_version and (not $this->nmqual)){
			my $nmdir = $this -> nm_directory;
			my $windows = 0;
			$windows=1 if ($Config{osname} eq 'MSWin32');
			my $suffix='';
			$suffix='.bat' if ($windows);
			#Try to figure out the subversion
			my $found = 0;
			foreach my $subv (('1','2','3','4','5','6','7','8','9')){
				last if $found;
				foreach my $path (@check_paths){
					my $script = "$nmdir$path"."nmfe7$subv$suffix"; 
					if( -x  $script){
						$this -> nm_minor_version($subv);
						$this->full_path_executable($script);
						$found = 1;
						$found_nonmem=1;
#						print "found minor\n";
						last;
					} 
				}
			}
		}
		if (defined $this -> nm_minor_version){
			#PsN.pm makes sure this is only one character, no dots
			#only want subversion number if subversion > 1
			$this -> nm_minor_version('') unless ($this -> nm_minor_version>1 );
		}else{
			$this -> nm_minor_version('');
		}
	}

	my $version = $this -> nm_major_version;
	my $subversion = $this -> nm_minor_version;
	my $nmdir = $this -> nm_directory;
	my $windows = 0;
	$windows=1 if ($Config{osname} eq 'MSWin32');


	my $nmfe='';
	my $suffix='';
	unless ($found_nonmem or $this->nmqual){
		$suffix='.bat' if ($windows);
		foreach my $path (@check_paths){
			$nmfe="$nmdir$path"."nmfe$version$subversion$suffix";
			if( -x $nmfe ){
				$this->full_path_executable($nmfe);
#				print "found version\n";
				$found_nonmem=1;
				last;
			} 
		}
	}


	if ($this->nmqual){
		if ( -x $this->nm_directory){
			if (-d $this->nm_directory){
				my $mess = "Error in PsN configuration, ".$this->nm_directory."\n".
					"which should be used with option -nm_version=".$this -> version." according to psn.conf\n".
					"is a directory, not a file, and thus cannot be an NMQual-generated perl-script.";
				$this -> store_message( message => $mess);
				$this -> error_message($mess);
				return 0;	  
			} else{
				$this->full_path_executable($this->nm_directory);
#				print "found nmqual\n";
				$found_nonmem = 1;
			}
		}else{
			my $err_version = ( defined $this->nm_directory and $this->nm_directory ne '' ) ? $this->nm_directory : '[not configured]';
			my $mess = "Unable to find the NMQual script ".$this->nm_directory."\n".
				"which should be used with option -nm_version=".$this -> version." according to psn.conf.";
			$this -> store_message( message => $mess);
			$this -> error_message($mess);
			return 0;
		}
	}else{
		#check if $nmdir is in fact name of executable script, then take that as nmfe (wrapper)
		unless ($found_nonmem){
			if(( -x "$nmdir" ) and (not -d "$nmdir")){
				$found_nonmem=1;
				$this->full_path_executable($nmdir);
#				print "found executable\n";
			
				if ($version == 7){
					if (defined $subversion){
						#PsN.pm makes sure this is only one character, no dots
						#only want subversion number if subversion == 2
						$subversion='' unless ($subversion==2 );
					}else{
						$subversion='';
					}
				}else{
					$subversion='';
				}
			}
		}
	}
	unless ($found_nonmem){
		my $looked_in= join ' or ',@check_paths;
		my $err_version = ( defined $nmdir and $nmdir ne '' ) ? $nmdir : '[not configured]';
		my $mess = "Unable to find executable nmfe$version$subversion$suffix ".
			"in any of the subdirectories\n".
			"$looked_in of the NONMEM installation directory.\n".
			"The NONMEM installation directory is $err_version for version [".
			$this -> version."] according to psn.conf.";
		$this -> store_message( message => $mess);
		$this -> error_message($mess);
		return 0;
	} 


}
# line 260 libgen/nonmem.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($this). '-> new');
	# End of Non-Dia code #

	return $this;
};

sub error_message {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'error_message'} = $parm;
	} else {
		return $self -> {'error_message'};
	}
}

sub fsubs {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'fsubs'} = $parm;
	} else {
		return $self -> {'fsubs'};
	}
}

sub display_iterations {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'display_iterations'} = $parm;
	} else {
		return $self -> {'display_iterations'};
	}
}

sub full_path_executable {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'full_path_executable'} = $parm;
	} else {
		return $self -> {'full_path_executable'};
	}
}

sub nmqual {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nmqual'} = $parm;
	} else {
		return $self -> {'nmqual'};
	}
}

sub nm_directory {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nm_directory'} = $parm;
	} else {
		return $self -> {'nm_directory'};
	}
}

sub nm_minor_version {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nm_minor_version'} = $parm;
	} else {
		return $self -> {'nm_minor_version'};
	}
}

sub nm_major_version {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nm_major_version'} = $parm;
	} else {
		return $self -> {'nm_major_version'};
	}
}

sub parafile {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'parafile'} = $parm;
	} else {
		return $self -> {'parafile'};
	}
}

sub nodes {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nodes'} = $parm;
	} else {
		return $self -> {'nodes'};
	}
}

sub nonmem_options {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nonmem_options'} = $parm;
	} else {
		return $self -> {'nonmem_options'};
	}
}

sub modelfile {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'modelfile'} = $parm;
	} else {
		return $self -> {'modelfile'};
	}
}

sub nice {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nice'} = $parm;
	} else {
		return $self -> {'nice'};
	}
}

sub nmtran_message {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'nmtran_message'} = $parm;
	} else {
		return $self -> {'nmtran_message'};
	}
}

sub outputfile {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'outputfile'} = $parm;
	} else {
		return $self -> {'outputfile'};
	}
}

sub version {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'version'} = $parm;
	} else {
		return $self -> {'version'};
	}
}

sub show_version {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'show_version'} = $parm;
	} else {
		return $self -> {'show_version'};
	}
}

sub adaptive {
	my $self = shift;
	my $parm = shift;

	# Start of Non-Dia code #
	# End of Non-Dia code #

	if( defined($parm) ){
		$self -> {'adaptive'} = $parm;
	} else {
		return $self -> {'adaptive'};
	}
}

sub store_message {
	my $self = shift;
	my %parm  = @_;
	my %valid_parm = ( 'message' => 'SCALAR', 'die_after' => 'SCALAR' );

	foreach my $givenp ( keys %parm ) {
		'debug' -> die( message => "ERROR in nonmem->store_message: Parameter \'$givenp\' is not valid" )
			unless( defined $valid_parm{$givenp} );

		if( $valid_parm{$givenp} =~ /^m_(.*)/ ){
			'debug' -> die( message => "ERROR in nonmem->store_message: You need to specify a \'$givenp\'!" )
				unless(defined $parm{$givenp});
			$valid_parm{$givenp} = $1;
		}

		if( $valid_parm{$givenp} eq 'SCALAR' or $valid_parm{$givenp} eq 'REF' ){
			'debug' -> die( message => "ERROR in nonmem->store_message: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref(\$parm{$givenp}))
				if( defined $parm{$givenp} and ref(\$parm{$givenp}) ne $valid_parm{$givenp} );
		} elsif( $parm{$givenp} =~ /=HASH\(/ and $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in nonmem->store_message: " . lc($valid_parm{$givenp}) . " parameter '$givenp' is of wrong type:" . lc(ref($parm{$givenp})) )
				if( defined $parm{$givenp} and lc(ref($parm{$givenp})) ne lc($valid_parm{$givenp}));
		} elsif( $valid_parm{$givenp} ne '' ) {
			'debug' -> die( message => "ERROR in nonmem->store_message: " . $valid_parm{$givenp} . " parameter '$givenp' is of wrong type:" . ref($parm{$givenp}))
				if( defined $parm{$givenp} and ref($parm{$givenp}) ne $valid_parm{$givenp} );
		}
	}

	my $message = $parm{'message'};
	my $die_after = defined $parm{'die_after'} ? $parm{'die_after'} : 0;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> store_message');
# line 514 "lib/nonmem_subs.pm" 
{ 
	open( ERR, '>>psn_nonmem_error_messages.txt' );
	print( ERR  $message);
	close (ERR);

	if ($die_after){
	    croak($message);
	}
}
# line 561 libgen/nonmem.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> store_message');
	# End of Non-Dia code #

}

sub run_with_nmfe {
	my $self = shift;
	my $return_value = 1;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> run_with_nmfe');
# line 210 "lib/nonmem_subs.pm" 
{

	my $version = $self -> nm_major_version;
	my $subversion = $self -> nm_minor_version;
	my $windows = 0;
	$windows=1 if ($Config{osname} eq 'MSWin32');
	my $nmfe = $self->full_path_executable();

	my @para_arr = ();
	if (defined $self->parafile() and ($self->parafile() ne 'none')){
		unless ($version == 7 and defined $subversion and $subversion >1){
			$self -> error_message("Cannot use parafile with NM7.1 or earlier\n");
			return 0;
		}
		push(@para_arr,'-parafile='.$self->parafile());
		if (defined $self->nodes() and ($self->nodes() > 0)){
			push(@para_arr,'[nodes]='.$self->nodes());;
		}
	}
	my @sw_arr = ();
	if (defined $self->nonmem_options() and ($self->nonmem_options() ne 'none')){
		my @switches = split( /,/ ,$self->nonmem_options());
		foreach my $sw (@switches){
			push(@sw_arr,' -'.$sw);
		}
	}

	# leave cleaning up to nmfe
	unless (defined $subversion and ($subversion > 0) and (length($subversion) > 0)){
		unlink( 'FMSG','FLIB','FCON', 'FDATA', 'FREPORT','FSUBS', 'FSUBS.f','FSUBS.f90','FSUBS2','nmprd4p.mod');
		unlink('fsubs','fsubs.f90',);
		unlink('LINK.LNK','FSTREAM', 'PRDERR', 'nonmem.exe', 'nonmem','FSUBS.for');
		unlink('nonmem5', 'nonmem6', 'nonmem7','nonmem5_adaptive', 'nonmem6_adaptive','nonmem7_adaptive' );
		unlink('ifort.txt','g95.txt','gfortran.txt','gfcompile.bat','g95compile.bat');
	}
	unlink('psn.lst','OUTPUT','output','nmfe_error');


	my $outputfile = $self -> outputfile;
	my $modelfile = $self -> modelfile;
	
	#need to add skiptr here for some cases if $subversion==2

	my ( $start_time, $fin_time );
	$start_time = localtime();

	if($windows){
		my $command ="$nmfe $modelfile $outputfile ";
		$command .= ' -background ' if ($self -> nm_major_version == 7);
		$command .= (join (' ',@para_arr)).' ' if (scalar(@para_arr)>0);
		$command .= (join (' ',@sw_arr)).' ' if (scalar(@sw_arr)>0);

		unless ($self->display_iterations()==1){
			$command .= ' > nmfe_output.txt';
		}
		system($command);
		$fin_time = localtime();
	} else {
		if ( -e "/proc/self/lock" ) {
			open (OUTFILE,">/proc/self/lock") || die "Could not unlock myself!\n";
			print OUTFILE "0";
			close (OUTFILE);
		}
		my $background = '';
		$background = '-background' if ($self -> nm_major_version == 7);
		if (scalar(@para_arr)>0){
			foreach my $par (@para_arr){
				$background .= ' '.$par; 
			}
		}
		if (scalar(@sw_arr)>0){
			foreach my $sw (@sw_arr){
				$background .= ' '.$sw; 
			}
		}

		my $submitstring = 'nice -n ' . $self -> nice . 
			" $nmfe $modelfile $outputfile ".$background ;
		unless ($self->display_iterations()==1){
			$submitstring = $submitstring .= ' > nmfe_output.txt' ;
		}
		print "\n$submitstring\n" if (0);
		system($submitstring); 

		if ( -e "/proc/self/lock" ) {
			open (OUTFILE,">/proc/self/lock") || die "Could not lock myself!\n";
			print OUTFILE "1";
			close (OUTFILE);
		}
		$fin_time = localtime();
	} 

	unless(-e 'FREPORT'){
		my $mess="NMtran failed. The following messages are in nmfe_output.txt:\n" ;
		open( FH, "<", 'nmfe_output.txt' );
		while( <FH> ){
			chomp;
			$mess .= " ".$_."\n";
		}
		close( FH );
		$self -> error_message($mess);
		$self -> store_message( message => $mess);
		return 0;
	}
	unless(-e "nonmem.exe" or -e "nonmem" ) {
		my $mess = "Fortran Compilation by $nmfe failed. No NONMEM executable produced.\n".
			"Run psn.mod in NM_runX subdirectory with $nmfe directly to diagnose the problem.";
		$self -> store_message( message => $mess);
		$self -> error_message($mess);
		return 0;
	}

	open( OUT, '>>', $outputfile );

	print( OUT  "This file was created using $nmfe\n" );
	print( OUT "Started  $start_time\n" );
	print( OUT "Finished $fin_time\n" );
	close( OUT );


}
# line 695 libgen/nonmem.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> run_with_nmfe');
	# End of Non-Dia code #

	return $return_value;
}

sub run_with_nmqual {
	my $self = shift;
	my $return_value = 1;

	# Start of Non-Dia code #
        'debug' -> warn(level => 3, message => "Entering \t" . ref($self). '-> run_with_nmqual');
# line 338 "lib/nonmem_subs.pm" 
{
#	print "run with nmqual\n";
	unless (defined $self -> nm_major_version){
		my $mess;
		open( FH, "<", 'psn_nonmem_error_messages.txt' );
		while( <FH> ){
			chomp;
			$mess .= " ".$_."\n";
		}
		close( FH );
		$self -> error_message($mess);
		return 0;
	}

	my $version = $self -> nm_major_version;
	my $subversion = $self -> nm_minor_version;
	my $nmqual = $self -> full_path_executable;
	my $windows = 0;
	$windows=1 if ($Config{osname} eq 'MSWin32');

	# clean up from old compile
	unless (defined $self -> nm_minor_version and 
			($self -> nm_minor_version > 0) and 
			(length($self -> nm_minor_version) > 0)){
		unlink( 'FMSG','FLIB','FCON', 'FDATA', 'FREPORT','FSUBS', 'FSUBS.f','FSUBS.f90','FSUBS2','nmprd4p.mod');
		unlink('fsubs','fsubs.f90','OUTPUT','output');
		unlink('LINK.LNK','FSTREAM', 'PRDERR', 'nonmem.exe', 'nonmem','FSUBS.for');
		unlink('nonmem5', 'nonmem6', 'nonmem7','nonmem5_adaptive', 'nonmem6_adaptive','nonmem7_adaptive' );
		unlink('ifort.txt','g95.txt','gfortran.txt','gfcompile.bat','g95compile.bat');
	}
	unlink('psn.nmqual_out','OUTPUT','output');
	unlink('psn.lst');


	my $outputfile = $self -> outputfile; #always psn.lst
	my $modelfile = $self -> modelfile; #always psn.mod
	my $command_string = '';

	my $nmqualoutput = 'psn.nmqual_out';
	my @para_arr = ();
	my @sw_arr = ();
	my $xml = '';

	if ($version == 7 and defined $subversion and $subversion >1){
		#assume NMQual8
		if (defined $self->parafile() and ($self->parafile() ne 'none')){
			push(@para_arr,'-parafile='.$self->parafile());
			if (defined $self->nodes() and ($self->nodes() > 0)){
				push(@para_arr,'[nodes]='.$self->nodes());;
			}
		}
		if (defined $self->nonmem_options() and $self->nonmem_options() ne 'none'){
			#assume NM7.2 or later
			my @optlist = split( /,/ ,$self->nonmem_options());
			$xml = $optlist[0];
			if ($optlist[1] ne 'none'){
				for (my $i=1;$i<scalar(@optlist);$i++){
					push(@sw_arr,' -'.$optlist[$i]);
				}
			}
		}else{
			my $mess = "Error when using nmqual and NONMEM7.2: nmqual_xml must be defined\n";
			$self -> store_message( message => $mess);
			$self -> error_message($mess);
			return 0;	  
		}
		my $wdir = cwd();
		$command_string = " $xml run ce $wdir psn ";
		$command_string .= join(' ',@para_arr).' ';
		$command_string .= join(' ',@sw_arr).' ';
	}else{
		$command_string = " $modelfile $nmqualoutput ";
	}
	print "perl $nmqual $command_string" if (0);

	my ( $start_time, $fin_time );
	$start_time = localtime();

	if($windows){
		my $perl_bin = 'perl';
		#change here? Ask Jeroen to test?
		if ($self->display_iterations()==1){
			system( "$perl_bin $nmqual $command_string");
		}else{
			system( "$perl_bin $nmqual $command_string > nmqual_messages.txt");
		}
		$fin_time = localtime();
	} else {
		my $perl_bin = 'perl';
		if ( -e "/proc/self/lock" ) {
			open (OUTFILE,">/proc/self/lock") || die "Could not unlock myself!\n";
			print OUTFILE "0";
			close (OUTFILE);
		}
		if ($self->display_iterations()==1){
			system( "nice -n " . $self -> nice . " $perl_bin $nmqual $command_string" ); 
		}else{
			system( "nice -n " . $self -> nice . " $perl_bin $nmqual $command_string > nmqual_messages.txt" ); 
		}
		if ( -e "/proc/self/lock" ) {
			open (OUTFILE,">/proc/self/lock") || die "Could not lock myself!\n";
			print OUTFILE "1";
			close (OUTFILE);
		}
		$fin_time = localtime();
	} 

	unless(-e 'FREPORT'){
		my $mess="NMtran failed. The following messages are in nmqual_messages.txt:\n" ;
		open( FH, "<", 'nmqual_messages.txt' );
		while( <FH> ){
			chomp;
			$mess .= " ".$_."\n";
		}
		close( FH );
		$self -> error_message($mess);
		$self -> store_message( message => $mess);
		return 0;
	}
	unless(-e "nonmem.exe" or -e "nonmem" ) {
		my $mess = "Fortran Compilation failed. No NONMEM executable produced.\n".
			"Run psn.mod in NM_runX subdirectory with $nmqual directly to diagnose the problem.";
		$self -> store_message( message => $mess);
		$self -> error_message($mess);
		return 0;
	}

	
	if (-e $outputfile){
		#NMQual8
		open( OUT, '>>', $outputfile );
	}else{
		cp( $modelfile, $outputfile ); #always prepend model to output, as nmfe
		open( OUT, '>>', $outputfile );
		#set autoflush for OUT to avoid problems finding psn.lst

		print(OUT "\n\n");
		if ($self -> nm_major_version == 7) {
			open( FH, "<", "FMSG" );
			while( <FH> ){
				chomp;
				print(OUT $_."\n");
			}
			close(FH);
			print(OUT "\n\n");
		}
		my $nmout = "OUTPUT";
		$nmout = "output" unless (-e "$nmout");
		if ( -e "$nmout" ){
			open( FH, "<", $nmout );
			while( <FH> ){
				chomp;
				print(OUT $_."\n");
			}
			close(FH);
			unlink( "$nmout" );
		} else {
			print "Warning: no file OUTPUT was produced by NMQual script $nmqual\n";
		}
	}

	print( OUT  "This file was created using $nmqual\n" );
	print( OUT "Started  $start_time\n" );
	print( OUT "Finished $fin_time\n" );
	close( OUT );

}
# line 876 libgen/nonmem.pm 
        'debug' -> warn(level => 3, message => "Leaving \t" . ref($self). '-> run_with_nmqual');
	# End of Non-Dia code #

	return $return_value;
}

1;

