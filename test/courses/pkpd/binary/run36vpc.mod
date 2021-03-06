$PROB simulation from run36

$INPUT ID TIME ODV DOSE ICL IV IKA 
       TYPE SMAX DV=SMXH THR CAV CAVH CON
       ;CNT CNT2 CNT3 HC HC2 HC3 
       ;ETA1 ETA2 ETA3 ETA4

$DATA data.csv IGNORE=@ ACCEPT=(THR.GT.0)

$PRED
  TVBASE = THETA(1)
  PHI    = LOG(TVBASE/(1-TVBASE)) + ETA(1)
  BASE   = EXP(PHI)/(1+EXP(PHI))

  IF(DV.GT.1) THEN
    Y=BASE
    RDV = 1  ; the "real" DV
  ENDIF
  IF(DV.LE.1) THEN 
    Y=1-BASE
    RDV = 0  ; the "real" DV
  ENDIF

  ; for simulation   
  IF(ICALL.EQ.4) THEN
    CALL RANDOM (2,R)
    DV=2
    ;IF(R.LE.BASE) RDV=1
    IF(R.GT.BASE) DV=0
  ENDIF

$THETA (0,.8)    ; BASE
$OMEGA 0.1         ; BSV BASE

$ESTIM MAXEVAL=9990 METHOD=COND LAPLACE LIKE PRINT=1 MSFO=msfb36
$SIM (12345) (678910 UNI) ONLY NOP NSUB=100

$TABLE ID TIME NOPRINT ONEHEADER FILE=sdtab36
$TABLE ID CAV CAVH CON NOPRINT ONEHEADER FILE=cotab36 
$TABLE ID DOSE NOPRINT ONEHEADER FILE=catab36
$TABLE ID ICL IV IKA NOPRINT ONEHEADER FILE=patab36



