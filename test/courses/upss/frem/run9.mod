;; 1. Based on: 9
;; 2. Description: FREM_BASE
;; x1. Author: Vijay Ivaturi
$PROBLEM    MOXONIDINE PK
;; Full Random Effects Model
$ABBREVIATED COMRES=20
$INPUT      ID VISI AGE SEX NYHA WT ACE DIG TAD TIME CRCL AMT SS II DV
            SORT TYPE
$DATA       mx20.csv IGNORE=@
$SUBROUTINE ADVAN2 TRANS1
$PK     

CL    = THETA(1)*EXP(ETA(1))
V     = THETA(1)*EXP(ETA(2))                
KA    = THETA(3)*EXP(ETA(3))
ALAG1 = THETA(4)
K     = CL/V
S2    = V

$ERROR     
WA     = THETA(5)
W      = WA
IPRED1 = LOG(.025)
IF(F.GT.0.AND.TYPE.EQ.0) IPRED1 = LOG(F)
IRES  = IPRED1-DV
IWRES = IRES/W
IF(TYPE.EQ.0) IPRED=IPRED1

Y0= IPRED
Y1=THETA(6)+ETA(4)    ; AGE
Y2=THETA(7)+ETA(5)    ; WT
Y3=THETA(8)+ETA(6)    ; CRCL
Y4=THETA(9)+ETA(7)    ; SEX
Y5=THETA(10)+ETA(8)   ; NYHA
Y6=THETA(11)+ETA(9)   ; ACE
Y7=THETA(12)+ETA(10)  ; DIG


IF(TYPE.EQ.0) Y= Y0+EPS(1)*W
IF(TYPE.EQ.1) Y= Y1 + EPS(2)
IF(TYPE.EQ.1) IPRED=Y1
IF(TYPE.EQ.2) Y= Y2 + EPS(2)
IF(TYPE.EQ.2) IPRED=Y2
IF(TYPE.EQ.3) Y= Y3 + EPS(2)
IF(TYPE.EQ.3) IPRED=Y3
IF(TYPE.EQ.4) Y= Y4 + EPS(2)
IF(TYPE.EQ.4) IPRED=Y4
IF(TYPE.EQ.5) Y= Y5 + EPS(2)
IF(TYPE.EQ.5) IPRED=Y5
IF(TYPE.EQ.6) Y= Y6 + EPS(2)
IF(TYPE.EQ.6) IPRED=Y6
IF(TYPE.EQ.7) Y= Y7 + EPS(2)
IF(TYPE.EQ.7) IPRED=Y7


$THETA  (0,27.3440) ; TVCL
 (0,109.7805) ; TVV
 (0,3.9496) ; TVKA
 0.217 FIX ; LAG
 (0,0.2883) ; RES ERR
 68.0541 ; AGE
 85.5801 ; WT
 67.0727 ; CLCR
 1.2003 ; SEX
 2.3199 ; NYHA
 0.5771 ; ACE
 0.6980 ; DIG
$OMEGA  BLOCK(10)
 0.0876
 0.02788 0.0594
 0.05606 0.01966 2.5893
 0.00042 0.00059 0.00082 64.7392
 0.00034 0.00054 0.0011 -11.93 264.2963
 0.00038 0.00048 0.0011 -51.1 230.0394 485.2246
 3E-05 3E-05 3E-05 -0.0093 -0.0896 -0.055 0.1571
 9E-05 9E-05 0.0001 0.07398 -0.0239 -0.1629 -0.0001 0.2707
 0.00011 0.00011 0.00011 -0.0274 -0.0464 0.14964 0.00051 -0.0049 0.2366
 8E-05 7E-05 9E-05 -0.0087 -0.122 -0.087 0.00084 0.00153 0.00157 0.2256
$SIGMA  1  FIX
$SIGMA  .0000001  FIX

$ESTIMATION METHOD=1 MAXEVALS=9999 PRINT=5 NOABORT NSIG=1
$COVARIANCE UNCONDITIONAL ; MATRIX=S
$TABLE      ID TIME IPRED IWRES CWRES NOPRINT ONEHEADER FILE=sdtab9
$TABLE      ID VISI AGE SEX NYHA WT ACE DIG TAD TIME CRCL AMT SS II DV
            TYPE ETA1 ETA2 ETA3 ETA4 ETA5 ETA6 ETA7 ETA8 ETA9 ETA10
            PRED NOPRINT NOAPPEND ONEHEADER FILE=mytab9
$TABLE      ID AGE SEX ACE DIG NYHA CRCL WT NOPRINT NOAPPEND ONEHEADER
            FILE=cotab9
