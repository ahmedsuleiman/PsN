#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 134;
#use Test::More;
use Test::Exception;
use lib ".."; #location of includes.pm
use includes; #file with paths to PsN packages
use ext::Math::MatrixReal qw(all); 
use Math::Trig;	# For pi
use Math::Random;
use output;
use tool::sir;
use FindBin qw($Bin);


#Tests needed for SIR

# sub get_user_covmatrix (from csv file, verify square and symmetric)


#sub resample

my $dir ="$Bin/../test_files/";
#my $dir='/home/kajsa/kod-psn/3PsN/devel/';
my $file='matrixreal.lst';
my $output= output -> new (filename => $dir.$file);

my $icm = tool::sir::get_nonmem_inverse_covmatrix(output => $output);

cmp_ok($icm->element(1,1),'==',8.46492E+06,'inverse element 1,1');
cmp_ok($icm->element(3,1),'==',9.12148E+03,'inverse element 3,1');
cmp_ok($icm->element(1,3),'==',9.12148E+03,'inverse element 1,3');
cmp_ok($icm->element(1,5),'==',-2.86424E+04,'inverse element 1,5');
cmp_ok($icm->element(4,2),'==',-1.55874E+02,'inverse element 4,2');
cmp_ok($icm->element(5,3),'==',-1.03606E+02,'inverse element 5,3');
cmp_ok($icm->element(5,5),'==',5.96396E+03,'inverse element 5,5');

my $hash = tool::sir::get_nonmem_parameters(output => $output);
my $thetas = $hash->{'filtered_values'};

cmp_ok($hash->{'filtered_values'}->[0],'==',5.55363E-03,' theta 1');
cmp_ok($hash->{'filtered_values'}->[1],'==',1.33638E+00,' theta 2');
cmp_ok($hash->{'filtered_values'}->[2],'==',4.97064E-01,' theta 3');
cmp_ok($hash->{'filtered_values'}->[3],'==',3.76272E-01,' theta 4');
cmp_ok($hash->{'filtered_values'}->[4],'==',1.28122E-01,' theta 5');
cmp_ok($hash->{'lower_bounds'}->[0],'==',0,' lower bound theta 1');
cmp_ok($hash->{'lower_bounds'}->[1],'==',0,' lower bound theta 2');
cmp_ok($hash->{'lower_bounds'}->[2],'==',0,' lower bound theta 3');
cmp_ok($hash->{'lower_bounds'}->[3],'==',0,' lower bound theta 4');
cmp_ok($hash->{'lower_bounds'}->[4],'==',0,' lower bound theta 5');
cmp_ok($hash->{'upper_bounds'}->[0],'==',1000000,' upper bound theta 1');
cmp_ok($hash->{'upper_bounds'}->[1],'==',1000000,' upper bound theta 2');
cmp_ok($hash->{'upper_bounds'}->[2],'==',1000000,' upper bound theta 3');
cmp_ok($hash->{'upper_bounds'}->[3],'==',1000000,' upper bound theta 4');
cmp_ok($hash->{'upper_bounds'}->[4],'==',1000000,' upper bound theta 5');
#$THETA  (0,0.0105) ; CL
#$THETA  (0,1.0500) ; V
#$THETA  (0,0.65)
#$THETA  (0,0.5)
#$THETA  (0,0.2)

#TODO test $hash->{'lower_bounds'} $hash->{'upper_bounds'} here

	#no static methods, must have an object for these methods
my $mat = new Math::MatrixReal(1,1);
my $mu = $mat->new_from_rows( [$thetas] );

#print $mu;


cmp_ok($mu->element(1,1),'==',5.55363E-03,'mu 1,1');
cmp_ok($mu->element(1,2),'==',1.33638E+00,'mu 1,2');
cmp_ok($mu->element(1,3),'==',4.97064E-01,'mu 1,3');
cmp_ok($mu->element(1,4),'==',3.76272E-01,'mu 1,4');
cmp_ok($mu->element(1,5),'==',1.28122E-01,'mu 1,5');

my $nsamples=3;

my $covar = tool::sir::get_nonmem_covmatrix(output => $output);

cmp_ok($covar->[0]->[0],'==',1.55838E-07,'covar element 1,1');
cmp_ok($covar->[1]->[1],'==',6.38430E-03,'covar element 2,2');
cmp_ok($covar->[1]->[2],'==',-1.94326E-03,'covar element 2,3');
cmp_ok($covar->[2]->[1],'==',-1.94326E-03,'covar element 3,2');
cmp_ok($covar->[3]->[2],'==',-1.32639E-03,'covar element 4,3');
cmp_ok($covar->[4]->[4],'==',eval(1.75502E-04),'covar element 5,5');

random_set_seed_from_phrase("hej pa dig");
my $gotsamples = tool::sir::sample_multivariate_normal(samples=>$nsamples,
													   covmatrix => $covar,
													   lower_bound => $hash->{'lower_bounds'},
													   upper_bound => $hash->{'upper_bounds'},
													   param => $hash->{'param'},
													   coords => $hash->{'filtered_coords'},
													   block_number => $hash->{'block_number'},
													   mu => $mu
	);

#print "\nxvec [".join(' ',@{$gotsamples->[2]})."]\n";
#print "\labels ".join(' ',@{$hash->{'labels'}})."\n";

my $sampled_params_arr = tool::sir::create_sampled_params_arr(samples_array => $gotsamples,
															  labels_hash => $hash);

cmp_ok(eval($sampled_params_arr->[0]->{'theta'}->{'CL'}),'==',0.00579867653819879,'sampled CL');
cmp_ok(eval($sampled_params_arr->[0]->{'theta'}->{'V'}),'==',1.20800900217457,'sampled V');
cmp_ok(eval($sampled_params_arr->[0]->{'theta'}->{'THETA3'}),'==',0.568698687977855,'sampled THETA3');
cmp_ok(eval($sampled_params_arr->[0]->{'theta'}->{'THETA4'}),'==',0.369700885223909,'sampled THETA4');
cmp_ok(eval($sampled_params_arr->[0]->{'theta'}->{'THETA5'}),'==',0.118821314516974,'sampled THETA5');


my $pdf=tool::sir::mvnpdf(inverse_covmatrix => $icm,
						  mu => $mu,
						  xvec_array => $gotsamples);
my $matlab_mvnpdf=4.622416072199147e+05; #mvnpdf function
cmp_ok(abs($pdf->[0]-$matlab_mvnpdf),'<',1e-7,'pdf diff to matlab');
#print "\npdf ".$pdf->[0]."\n";


my $wghash = tool::sir::compute_weights(pdf_array => $pdf,
										dofv_array => [1,10,5]);

cmp_ok(abs($wghash->{'weights'}->[0]-1.312150724294432e-06),'<',0.000000000001e-06,'weight 1');
cmp_ok(abs($wghash->{'weights'}->[1]-5.059816747224142e-09),'<',0.000000000001e-09,'weight 2');
cmp_ok(abs($wghash->{'weights'}->[2]-3.077141488472004e-08),'<',0.000000000001e-08,'weight 3');

cmp_ok(abs($wghash->{'cdf'}->[0]-1.312150724294432e-06),'<',0.000000000001e-06,'cdf 1');
cmp_ok(abs($wghash->{'cdf'}->[1]-1.317210541041656e-06),'<',0.000000000001e-06,'cdf 2');
cmp_ok(abs($wghash->{'cdf'}->[2]-1.347981955926376e-06),'<',0.000000000001e-06,'cdf 3');


tool::sir::recompute_weights(weight_hash => $wghash,
							 reset_index => 1);

cmp_ok(abs($wghash->{'weights'}->[0]-1.312150724294432e-06),'<',0.000000000001e-06,'weight 1 recompute');
cmp_ok($wghash->{'weights'}->[1],'==',0,'weight 2 recompute');
cmp_ok(abs($wghash->{'weights'}->[2]-3.077141488472004e-08),'<',0.000000000001e-08,'weight 3 recompute');

cmp_ok(abs($wghash->{'cdf'}->[0]-1.312150724294432e-06),'<',0.000000000001e-06,'cdf 1 recompute');
cmp_ok(abs($wghash->{'cdf'}->[1]-1.312150724294432e-06),'<',0.000000000001e-06,'cdf 2 recompute');
cmp_ok(abs($wghash->{'cdf'}->[2]-1.342922139179152e-06),'<',0.000000000001e-06,'cdf 3 recompute');


tool::sir::recompute_weights(weight_hash => $wghash,
							 reset_index => 0);

cmp_ok($wghash->{'weights'}->[0],'==',0,'weight 1 recompute');
cmp_ok($wghash->{'weights'}->[1],'==',0,'weight 2 recompute');
cmp_ok(abs($wghash->{'weights'}->[2]-3.077141488472004e-08),'<',0.000000000001e-08,'weight 3 recompute');

cmp_ok($wghash->{'cdf'}->[0],'==',0,'cdf 1 recompute');
cmp_ok($wghash->{'cdf'}->[1],'==',0,'cdf 2 recompute');
cmp_ok(abs($wghash->{'cdf'}->[2]-3.077141488472004e-08),'<',0.000000000001e-08,'cdf 3 recompute');

#start over
$wghash = tool::sir::compute_weights(pdf_array => $pdf,
									 dofv_array => [9.8,8.1,9.5]);

my @times_sampled = (0) x $nsamples;

my $sample_index = tool::sir::weighted_sample(cdf => $wghash->{'cdf'});
$times_sampled[$sample_index]++;
#print "times sampled ".join(' ',@times_sampled)."\n";
tool::sir::recompute_weights(weight_hash => $wghash,
							 reset_index => $sample_index);
$sample_index = tool::sir::weighted_sample(cdf => $wghash->{'cdf'});
$times_sampled[$sample_index]++;
#print "times sampled ".join(' ',@times_sampled)."\n";

tool::sir::recompute_weights(weight_hash => $wghash,
							 reset_index => $sample_index);
$sample_index = tool::sir::weighted_sample(cdf => $wghash->{'cdf'});
$times_sampled[$sample_index]++;
#print "times sampled ".join(' ',@times_sampled)."\n";


#start over
$wghash = tool::sir::compute_weights(pdf_array => $pdf,
									 dofv_array => [9.8,8.1,9.5]);

my @times_sampled = (0) x $nsamples;

for (my $k=0; $k< 100; $k++){
	my $sample_index = tool::sir::weighted_sample(cdf => $wghash->{'cdf'});
	$times_sampled[$sample_index]++;
}
#print "times sampled ".join(' ',@times_sampled)."\n";
cmp_ok($times_sampled[0],'==',39,'times sampled 0');
cmp_ok($times_sampled[1],'==',46,'times sampled 1');
cmp_ok($times_sampled[2],'==',15,'times sampled 2');

#my $statshash = tool::sir::empirical_statistics(samples_array => $gotsamples,
#												sample_counts => \@times_sampled);


my $xvec = $icm->new_from_rows( [$gotsamples->[0]] );
#print $xvec;
#exit;
my $diff=$mu->shadow(); #zeros matrix same size as $mu
$diff->subtract($xvec,$mu); #now $diff is $xvec - $mu
#print $diff;

my $matlab_invdeterminant =1.952310799901186e+17;
my $invdeterminant = $icm->det();
cmp_ok(abs($invdeterminant-$matlab_invdeterminant),'<',420,'invdeterminant diff to matlab'); #relative diff is 2e-15

my $determinant=1/$invdeterminant;
my $matlab_determinant =5.122135266836687e-18;
cmp_ok(abs($determinant-$matlab_determinant),'<',1e-31,'determinant diff to matlab');

my $k=5;

my $product_left = $diff->multiply($icm);
my $product=$product_left->multiply(~$diff); #~ is transpose
my $exponent=-0.5 * $product->element(1,1);

my $matlab_exponent= -2.267944479995964;
cmp_ok(abs($exponent-$matlab_exponent),'<',1e-14,'exponent diff to matlab');

#print "\nexponent $exponent\n";
my $base=tool::sir::get_determinant_factor(inverse_covmatrix => $icm,
										   k => $k);

#print "\nbase $base\n";
my $matlab_base = 4.465034382516543e+06;
cmp_ok(abs($base-$matlab_base),'<',0.00000001,'base diff to matlab');


$dir ="$Bin/../test_files/";
#$dir='temp/';
$file='mox_sir.lst';
$output= output -> new (filename => $dir.$file);

my $icm = tool::sir::get_nonmem_inverse_covmatrix(output => $output);

cmp_ok($icm->element(1,1),'==',eval(4.05821E-01),'inverse element 1,1');
cmp_ok($icm->element(3,1),'==',5.71808E+00,'inverse element 3,1');
cmp_ok($icm->element(1,3),'==',5.71808E+00,'inverse element 1,3');
cmp_ok($icm->element(1,5),'==',-3.17183E+00,'inverse element 1,5');
cmp_ok($icm->element(4,2),'==',1.38220E+01,'inverse element 4,2');
cmp_ok($icm->element(5,3),'==',-2.66596E+02,'inverse element 5,3');
cmp_ok($icm->element(5,5),'==',1.48718E+04,'inverse element 5,5');
cmp_ok($icm->element(6,2),'==',-7.76844E-01,'inverse element 6,2');
cmp_ok($icm->element(5,6),'==',-3.88572E+02,'inverse element 5,6');
cmp_ok($icm->element(6,6),'==',3.04099E+02,'inverse element 6,6');
cmp_ok($icm->element(1,7),'==',-4.35392E-02,'inverse element 1,7');
cmp_ok($icm->element(7,3),'==',-6.35795E+01,'inverse element 7,3');
cmp_ok($icm->element(7,7),'==',2.50300E+01,'inverse element 7,7');
cmp_ok($icm->element(8,3),'==',3.32151E+02,'inverse element 8,3');
cmp_ok($icm->element(5,8),'==',-4.85426E+02,'inverse element 5,8');
cmp_ok($icm->element(8,7),'==',-2.94627E+00,'inverse element 8,7');
cmp_ok($icm->element(8,8),'==',6.84766E+02,'inverse element 8,8');

$hash = tool::sir::get_nonmem_parameters(output => $output);

my $params = $hash->{'filtered_values'};

cmp_ok($hash->{'filtered_values'}->[0],'==',3.28661E+01,' theta 1');
cmp_ok($hash->{'filtered_values'}->[1],'==',2.10323E+01,' theta 2');
cmp_ok($hash->{'filtered_values'}->[2],'==',2.92049E-01,' theta 3');
cmp_ok($hash->{'filtered_values'}->[3],'==',9.91440E-02,' theta 4');
cmp_ok($hash->{'filtered_values'}->[4],'==',3.34511E-01,' theta 5');
cmp_ok($hash->{'filtered_values'}->[5],'==',4.08636E-01,' OM 1,1');
cmp_ok($hash->{'filtered_values'}->[6],'==',1.10186E+00,' OM 2,2');
cmp_ok($hash->{'filtered_values'}->[7],'==',2.07708E-01,' OM 3,3');
cmp_ok($hash->{'lower_bounds'}->[0],'==',0,' lower bound theta 1');
cmp_ok($hash->{'lower_bounds'}->[1],'==',0,' lower bound theta 2');
cmp_ok($hash->{'lower_bounds'}->[2],'==',0,' lower bound theta 3');
cmp_ok($hash->{'lower_bounds'}->[3],'==',0,' lower bound theta 4');
cmp_ok($hash->{'lower_bounds'}->[4],'==',0,' lower bound theta 5');
cmp_ok($hash->{'lower_bounds'}->[5],'==',0,' lower bound OM 1,1');
cmp_ok($hash->{'lower_bounds'}->[6],'==',0,' lower bound OM 2,2');
cmp_ok($hash->{'lower_bounds'}->[7],'==',0,' lower bound OM 3,3');
cmp_ok($hash->{'upper_bounds'}->[0],'==',1000000,' upper bound theta 1');
cmp_ok($hash->{'upper_bounds'}->[1],'==',1000000,' upper bound theta 2');
cmp_ok($hash->{'upper_bounds'}->[2],'==',1000000,' upper bound theta 3');
cmp_ok($hash->{'upper_bounds'}->[3],'==',1000000,' upper bound theta 4');
cmp_ok($hash->{'upper_bounds'}->[4],'==',1000000,' upper bound theta 5');
cmp_ok($hash->{'upper_bounds'}->[5],'==',1000000,' upper bound OM 1,1');
cmp_ok($hash->{'upper_bounds'}->[6],'==',1000000,' upper bound OM 2,2');
cmp_ok($hash->{'upper_bounds'}->[7],'==',1000000,' upper bound OM 3,3');

cmp_ok($hash->{'filtered_coords'}->[3],'eq','4',' coord theta 4');
cmp_ok($hash->{'filtered_coords'}->[4],'eq','5',' coord theta 5');
cmp_ok($hash->{'filtered_coords'}->[5],'eq','1,1',' coord OM 1,1');
cmp_ok($hash->{'filtered_coords'}->[6],'eq','2,2',' coord OM 2,2');
cmp_ok($hash->{'filtered_coords'}->[7],'eq','3,3',' coord OM 3,3');

$mu = $mat->new_from_rows( [$params] );

#print $mu;

cmp_ok($mu->element(1,1),'==',3.28661E+01,'mu 1,1');
cmp_ok($mu->element(1,8),'==',2.07708E-01,'mu 1,8');

#my $nsamples=3;

$covar = tool::sir::get_nonmem_covmatrix(output => $output);

cmp_ok($covar->[0]->[0],'==',6.10693E+00,'covar element 1,1');
cmp_ok($covar->[1]->[5],'==',1.18743E-02,'covar element 2,6');
cmp_ok($covar->[2]->[2],'==',3.75907E-04,'covar element 3,3');
cmp_ok($covar->[3]->[1],'==',-4.02777E-02,'covar element 4,2');
cmp_ok($covar->[4]->[7],'==',6.19395E-05,'covar element 5,8');
cmp_ok($covar->[7]->[0],'==',1.53110E-02,'covar element 8,1');
cmp_ok($covar->[6]->[5],'==',7.25938E-03,'covar element 7,6');
cmp_ok($covar->[7]->[7],'==',1.69362E-03,'covar element 8,8');
cmp_ok($covar->[6]->[3],'==',2.75131E-03,'covar element 7,4');
cmp_ok($covar->[4]->[6],'==',-3.05686E-04,'covar element 5,7');

tool::sir::inflate_covmatrix(matrix => $covar,
							 inflation => 2);

cmp_ok($covar->[0]->[0],'==',eval(2*6.10693E+00),'inflated covar element 1,1');
cmp_ok($covar->[1]->[5],'==',eval(2*1.18743E-02),'inflated covar element 2,6');
cmp_ok($covar->[2]->[2],'==',eval(2*3.75907E-04),'inflated covar element 3,3');
cmp_ok($covar->[3]->[1],'==',eval(2*-4.02777E-02),'inflated covar element 4,2');
cmp_ok($covar->[4]->[7],'==',eval(2*6.19395E-05),'inflated covar element 5,8');
cmp_ok($covar->[7]->[0],'==',eval(2*1.53110E-02),'inflated covar element 8,1');
cmp_ok($covar->[6]->[5],'==',eval(2*7.25938E-03),'inflated covar element 7,6');
cmp_ok($covar->[7]->[7],'==',eval(2*1.69362E-03),'inflated covar element 8,8');
cmp_ok($covar->[6]->[3],'==',eval(2*2.75131E-03),'inflated covar element 7,4');
cmp_ok($covar->[4]->[6],'==',eval(2*-3.05686E-04),'inflated covar element 5,7');


$dir ="$Bin/../test_files/";
#$dir='temp/';
$file='mox_sir_block2.lst';
$output= output -> new (filename => $dir.$file);

$hash = tool::sir::get_nonmem_parameters(output => $output);

$params = $hash->{'filtered_values'};

#cmp_ok($hash->{'filtered_values'}->[0],'==',3.28661E+01,' theta 1');

$mu = $mat->new_from_rows( [$params] );

#print $mu;
$covar = tool::sir::get_nonmem_covmatrix(output => $output);

cmp_ok($covar->[7]->[6],'==',eval(3.36412E-02),'covar element 8,7');
cmp_ok($covar->[8]->[7],'==',eval(2.52026E-03),'covar element 9,8');


$nsamples=3;

#random_set_seed_from_phrase("hej pa dig");
my $gotsamples = tool::sir::sample_multivariate_normal(samples=>$nsamples,
													   covmatrix => $covar,
													   lower_bound => $hash->{'lower_bounds'},
													   upper_bound => $hash->{'upper_bounds'},
													   param => $hash->{'param'},
													   coords => $hash->{'filtered_coords'},
													   block_number => $hash->{'block_number'},
													   mu => $mu
	);




done_testing();