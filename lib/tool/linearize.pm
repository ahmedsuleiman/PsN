package tool::linearize;

use Moose;
use MooseX::Params::Validate;
use File::Path;
use File::Copy 'cp';
use tool;
use tool::scm;

has 'epsilon' => ( is => 'rw', isa => 'Bool', default => 1 );
has 'foce' => ( is => 'rw', isa => 'Bool', default => 1 );
has 'error' => ( is => 'rw', isa => 'Maybe[Str]' );

extends 'tool';

sub BUILD
{
}

sub modelfit_setup
{
    my $self = shift;
    my %parm = validated_hash(\@_,
		model_number => { isa => 'Int', optional => 1 }
	);
	my $model_number = $parm{'model_number'};

	my $model = $self->models->[$model_number - 1];

    my $lstfile;
    if (-e $model->outputs->[0]->full_name()){
        $lstfile = $model->outputs->[0]->full_name();
    }

    if ($model->is_option_set(record => 'abbreviated', name => 'REPLACE')) {
        print "\nWARNING: Option REPLACE used in \$ABBREVIATED. This can lead to serious errors.\n\n";
    }

    my @keep;
    foreach my $option (@{$model->problems->[0]->inputs->[0]->options()}){
        push (@keep, $option->name() ) if ( not ($option -> value eq 'DROP' or $option -> value eq 'SKIP'
                    or $option -> name eq 'DROP' or $option -> name eq 'SKIP'
                    or $option->name eq 'ID' or $option->name eq 'DV' 
                    or $option->name eq 'MDV'));
    }
    #set do not drop to everything undropped in model

    my $scm = tool::scm->new(
		%{common_options::restore_options(@common_options::tool_options)},
        models => [ $model ],
        epsilon => $self->epsilon,
        foce => $self->foce,
        do_not_drop => \@keep,
        lst_file => $lstfile,
        error => $self->error,
        search_direction => 'forward',
        linearize => 1,
        max_steps => 0,
        test_relations => {},
        categorical_covariates => [],
        continuous_covariates  => [],
        both_directions => 0,
        logfile => ['linlog.txt'],
    );

    $scm->run;

    #cleanup
    rmtree([ $scm->directory . 'm1' ]);
    rmtree([ $scm->directory . 'final_models' ]);
    unlink($scm->directory . 'covariate_statistics.txt');
    unlink($scm->directory . 'relations.txt');
    unlink($scm->directory . 'short_scmlog.txt');
    unlink($scm->directory . 'original.mod');
    unlink($scm->directory . 'base_model.mod');
    my @files = glob($scm->directory . $scm->basename . '*');
    for my $file (@files) {
        cp($file, '.');
    }

    cp($scm->basename . '.dta', '../' . $scm->basename . '.dta');
    cp($scm->basename . '.mod', '../' . $scm->basename . '.mod');
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
