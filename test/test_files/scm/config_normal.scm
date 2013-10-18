model=pheno_with_cov.mod
search_direction=forward
logfile=scmlog1.txt
p_forward=0.05

continuous_covariates=WGT,APGR,CV1,CV2,CV3
categorical_covariates=CVD1,CVD2,CVD3

[test_relations]
CL=WGT,APGR,CV1,CV2,CV3
V=CVD1

[valid_states]
continuous = 1,2,3,4,5
categorical = 1,2

[included_relations]
CL=WGT-1,APGR-2,CV1-3,CV2-4,CV3-5
V=CVD1-2
