package nonmemrun::slurm;

use include_modules;
use Moose;
use MooseX::Params::Validate;

extends 'nonmemrun';

has 'partition' => ( is => 'rw', isa => 'Maybe[Str]' );
has 'account' => ( is => 'rw', isa => 'Maybe[Str]' );

sub submit
{
	my $self = shift;
	my $jobId = -1;

	$self->pre_compile_cleanup;

	#only support nmfe here, not nmqual

	my $jobname = $self->model->filename;
	$jobname = 'psn_' . $jobname if ($jobname =~ /^[0-9]/);

	#cwd default in slurm
	# -J jobname
	#need to check translation for -b y

	my $flags = ' -J ' . $jobname;
	$flags .= ' -o nmfe.output -e nmfe.output ';
	if (defined $self->account) {
		$flags .= ' -A ' . $self->account;
	} else {
		if ($PsN::config -> {'default_options'} -> {'uppmax'}) {
			croak("slurm account must be defined on uppmax");
		}
	}
	if (defined $self->max_runtime) {
		#Acceptable time formats include #minutes", 
		#minutes:seconds", #hours:minutes:seconds", #days-hours", 
		#days-hours:minutes¡ and ´days-hours:minutes:seconds". 
		unless (($self->max_runtime =~ /^[0-9]+$/) or
				($self->max_runtime =~ /^[0-9]+\:[0-9]+\:[0-9]+$/) or
				($self->max_runtime =~ /^[0-9]+\-[0-9]+$/)) {
			croak("max_runtime must have format minutes, hours:minutes:seconds, or days-hours");
		}
		$flags .= ' -t ' . $self->max_runtime ;
	}
	if (defined $self->partition) {
		$flags .= ' -p ' . $self->partition;
	}
	#at most 3GB RAM 
	if ($PsN::config->{'default_options'}->{'uppmax'}) {
		$flags .= ' -p core -n 1 '; #single core
	}

	if (defined $self->send_email and defined $self->email_address) {
		if ($self->send_email eq 'ALL') {
			$flags .= ' --mail-user='.$self->email_address . ' --mail-type=ALL ';
		} else {
			$flags .= ' --mail-user='.$self->email_address . ' --mail-type=END ';
		}
	}

	#-t "hours:minutes:seconds", "days-hours"

	#sbatch -J psn:pheno.mod -o nmfe.output -e nmfe.output -p core -n 1 -t 0:3:0 -A p2011021 /bubo/sw/apps/nonmem/nm_7.1.0_g_reg/run/nmfe7 pheno.mod pheno.lst -background

	if (defined $self->prepend_flags) {
		$flags = ' ' . $self->prepend_flags . $flags;
	}
	my $nmfe_command = $self->create_nmfe_command;

	my $submitstring = $flags . ' ' . $nmfe_command;

	system('echo sbatch ' . $submitstring . ' "2>&1" > sbatchcommand');

	for (my $i = 0; $i < 10; $i++) {
		sleep(1); #wait to let other nodes sync files here?
		my $outp = `sbatch $submitstring 2>&1`;
		#write error to job_submission_error instead, set jobid to -1, and continue?
		if ($outp =~ /Submitted batch job (\d+)/) {
			$jobId = $1;
			last;
		} elsif($outp =~ /Socket timed out/) {
			#try again. jobId is -1 by initiation 
			sleep(3);
			next;
		} else {
			print "Slurm submit failed.\nSystem error message: $outp\nConsidering this model failed.";
			system('echo ' . $outp . '  > job_submission_error');
			$jobId = -1;
			last;
		}	
	}
	system('echo sbatch '.$jobId.' "2>&1" > jobId');

	return $jobId;
}


sub monitor
{
	my $self = shift;
	my %parm = validated_hash(\@_,
		jobId => { isa => 'Int', optional => 1 }
	);
	my $jobId = $parm{'jobId'};

	#squeue -j 12345, --jobs

	#list only completed, cancelled... job with right id without header
	my $outp = `squeue -h --states CA,CD,F,NF,TO -j $jobId 2>&1`;
	if (defined $outp) {
		if ($outp =~ /(i|I)nvalid/) {
			#this is either because the job finished so long ago (MinJobAge)
			#that is has disappeared, 
			#or due to some Slurm error. We sleep for 3 sec to make sure there was not an error
			#due to too early polling, and then try again. If message persists then assume job
			#id will never be valid, i.e. finished. That definitely can happen.
			sleep(3);
			my $outp2 = `squeue -h --states CA,CD,F,NF,TO -j $jobId 2>&1`;
			if (defined $outp2) {
				if ($outp2 =~ /(i|I)nvalid/) {
					return $jobId; # Give up. This job is finished since not in queue
				} elsif ($outp2 =~ /^\s*$jobId\s/) {
					#assume jobId first item in string, possibly with leading whitespace
					#job is finished
					return $jobId;
				} else {
					return 0; # Assume some error message, not finished
				}
			} else {
				return 0; # not finished since empty output when asking for finished jobs
			}
		} elsif ($outp =~ /^\s*$jobId\s/) {
			#assume jobId first item in string, possibly with leading whitespace
			#job in set of finished ones
			return $jobId;
		} else {
			return 0; #Assume some error message, not finished
		}
	} else {
		return 0; # Not finished since empty output
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;