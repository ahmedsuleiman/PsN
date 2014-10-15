$PROBLEM    STUDY DESIGN COURSE
$INPUT      ID DOSE TIME DV ARM CRCL MDV MDV2 CFB
;ID    - 10000 subjects (1000 per arm)
;DOSE  - 10 doses: 0,5,10,20,30,45,60,75,90,120 mg 
;TIME  - 4 observation times: 0,1,2,3
;DV    - response variable ;note output will be MEAN response
$DATA       data19.csv IGNORE=@ 
$PRED
;Sim_start
;  BASELINE    = THETA(1)*EXP(ETA(1))  
;  PLACEBO_MAX = THETA(2)* (1+ETA(2))    
;  PLACEBO_HL  = THETA(3) 
;  EMAX        = THETA(4)*EXP(ETA(3))
;  ED50        = THETA(5)
;  PLACEBO     = PLACEBO_MAX*(1-EXP(-LOG(2)/PLACEBO_HL*TIME)) 
;  IPRED       = BASELINE + PLACEBO + EMAX*DOSE/(ED50+DOSE) 
;  Y1          = IPRED + EPS(1)
;  
; IF(NEWIND.EQ.0) THEN
;  M_0_3=0
;  M_5_3=0
;  M_10_3=0
;  M_20_3=0
;  M_30_3=0
;  M_45_3=0
;  M_60_3=0
;  M_75_3=0
;  M_90_3=0
;  M_120_3=0
;  NFLG=1000
; ENDIF
;  IF(ARM.EQ.0.AND.TIME.EQ.3) M_0_3=Y1+M_0_3
;  IF(ARM.EQ.5.AND.TIME.EQ.3) M_5_3=Y1+M_5_3
;  IF(ARM.EQ.10.AND.TIME.EQ.3) M_10_3=Y1+M_10_3
;  IF(ARM.EQ.20.AND.TIME.EQ.3) M_20_3=Y1+M_20_3
;  IF(ARM.EQ.30.AND.TIME.EQ.3) M_30_3=Y1+M_30_3
;  IF(ARM.EQ.45.AND.TIME.EQ.3) M_45_3=Y1+M_45_3
;  IF(ARM.EQ.60.AND.TIME.EQ.3) M_60_3=Y1+M_60_3
;  IF(ARM.EQ.75.AND.TIME.EQ.3) M_75_3=Y1+M_75_3
;  IF(ARM.EQ.90.AND.TIME.EQ.3) M_90_3=Y1+M_90_3
;  IF(ARM.EQ.120.AND.TIME.EQ.3) M_120_3=Y1+M_120_3
;   Y=0
;   IF(ARM.EQ.5.AND.TIME.EQ.3)  Y=M_5_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.10.AND.TIME.EQ.3)  Y=M_10_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.20.AND.TIME.EQ.3)  Y=M_20_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.30.AND.TIME.EQ.3)  Y=M_30_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.45.AND.TIME.EQ.3)  Y=M_45_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.60.AND.TIME.EQ.3)  Y=M_60_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.75.AND.TIME.EQ.3)  Y=M_75_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.90.AND.TIME.EQ.3)  Y=M_90_3 /NFLG-M_0_3/NFLG
;   IF(ARM.EQ.120.AND.TIME.EQ.3)  Y=M_120_3 /NFLG-M_0_3/NFLG

;$SIML (987987) ONLYSIM
  BASELINE    = THETA(1)*EXP(ETA(1))  
  PLACEBO_MAX = THETA(2)* (1+ETA(2))    
  PLACEBO_HL  = THETA(3) 
  EMAX        = THETA(4)*EXP(ETA(3))
  ED50        = THETA(5)
  PLACEBO     = PLACEBO_MAX*(1-EXP(-LOG(2)/PLACEBO_HL*TIME)) 
  IPRED       = BASELINE + PLACEBO + EMAX*DOSE/(ED50+DOSE) 
  Y           = IPRED + EPS(1)
$EST METH=1 MAX=0

;Sim_end  

$THETA  97.7078 ; 1_BASELINE
$THETA  22.759 ; 2_PLACEBO_MAX
$THETA  0.745253 ; 3_PLACEBO_HL
$THETA  20.556133 ; 4_EMAX
$THETA  20.556133 ; 5_ED50
$OMEGA  BLOCK(2)
 0.232539  ; 1_OM_BASELINE
 -0.021345 0.113703  ; 2_OM_PLC_MAX
$OMEGA  0.107531  ;   3_OM_EMAX
$SIGMA  127.891  ;    1_SIGMA