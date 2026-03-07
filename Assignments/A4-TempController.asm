; FileName: TempController
; Author: Geovani Palomec
; Date: 3/7/26
; MPLAB Version: v6.30
;------------------------------------------------------------------------------
; Program Vervsion: V4 
; Patch notes of V; Implemented another dependency and PSECT, worked on comments
; Purpose: Measure, Set and adjust temp accordingly.
; Inputs: Temperature readings
; Outputs: Outputs temp readings
; Instructions:Input values under program mem 
    ;On Reading the System results: 
    //SYSTEM OFF
	; contReg = 0
	; PORTD1=0, 
	; PORTD2=0 
    //HEAT ON
	; contReg = 2 
	; PORTD1=0
	; PORTD2=1 
    //COOL ON
	; contReg = 1
	; PORTD1=1
	; PORTD2=0  	
; Dependencies:	<xc.inc>, <AssemblyConfig.inc>
    
processor 18F47K42
#include <xc.inc>
#include "AssemblyConfig.inc"
    
PSECT absdata,abs,ovrld        ; Do not change

;----------------
; PROGRAM INPUTS
;----------------
    ;The DEFINE directive is used to create macros or symbolic names for values.
    ;It is more flexible and can be used to define complex expressions or 
    ;sequences of instructions. It is processed by the preprocessor before 
    ;assembly begins.
    
    #define  refTempInput       15	; between +10 and +50 Degree celsius. 
    #define  measuredTempInput  -5	;between -10 and +60 Degree Celsius

;---------------------
; Definitions
;---------------------
    #define SWITCH    LATD,2  
    #define LED0      LATD,0
    #define LED1      LATD,1

;---------------------
; Program Constants 
;---------------------
; The EQU (Equals) directive is used to assign a constant value to a symbolic 
;name or label. It is simpler and is typically used for straightforward 
; assignments. It directly substitutes the defined value into the code 
;during the assembly process.
    REG10   equ     10h // in Hex
    REG11   equ     11h
    REG01   equ     1h

;----------------------------
; Constants defined with proper register numbers (R8)
;----------------------------
   
    refTempReg   equ 20h   ; refTemp -> REG 0x20
    measTempReg  equ 21h   ; measuredTemp -> REG 0x21
    contReg      equ 22h   ; contReg -> REG 0x22

    ;constants used for conversion
    count        equ 30h
    number       equ 31h
    tmp          equ 32h

    ; BCD output constants
    ; REF digits:
    REF_ONES     equ 60h   ; ones digit of ref temp (ex: 44 -> 4)
    REF_TENS     equ 61h   ; tens digit of ref temp (ex: 44 -> 4)
    REF_HUND     equ 62h   ; hundreds digit (almost always 0 here)

    ; MEASURED digits:
    MEA_ONES     equ 70h
    MEA_TENS     equ 71h
    MEA_HUND     equ 72h

    org 0x000
    goto main
    
;----------------------------
; Main program starts at 0x20 
;----------------------------
    org 0x020	;R7 start from register 0x20 in the program memory.
main:
    
    ; R6 Initialize LATD ONLY as outputs and clear 
    banksel TRISD
    clrf    TRISD	; make LATD pins outputs
    
   ;Copy into LatPortD
    banksel ANSELD	;Analog Select Register for Port D
    clrf    ANSELD      ; make PORTD pins digital
    
    banksel LATD
    clrf    LATD	; start with LATD all OFF
    banksel LATD
    clrf    LATD	;clear latch
    
    ; Put the ARBITRARY TEST values 
    movlw   refTempInput	    ; refTemp  
    banksel refTempReg
    movwf   refTempReg
    
    movlw   measuredTempInput	    ; measuredTemp 
    banksel measTempReg
    movwf   measTempReg

; ----------------------------
; Performs comparison
; ----------------------------
    banksel measTempReg
    btfsc   measTempReg, 7    ; if measured negative -> treat as HEAT
    goto    SET_HEAT
    
    banksel refTempReg
    movf    refTempReg, W
    banksel measTempReg
    subwf   measTempReg, W  ; W = measured - ref  (status bits set)

    ;If measuredTemp = refTemp, Z=1, then set contReg=0 goto ledoff
    btfsc   STATUS, 2	   
    goto    SET_EQUAL	    ;LED OFF 

    ;If measuredTemp > refTemp then set contReg=2 
    ;C=1 (no borrow) indicates measured > ref
    btfsc   STATUS, 0      
    goto    SET_COOL	    ;LED is HOT

    ; Else measured < ref set contReg=1 
    goto    SET_HEAT	    ;LED is COOL
    
; ----------------------------
; Branch targets implementing actions R1-R3
; ----------------------------
SET_EQUAL:
    ;set contReg=0
    movlw   0x00
    banksel contReg
    clrf    contReg
    goto    LED_OFF

SET_COOL:
    ;set contReg=1 (cooler is on) LATD2=1
    movlw   0x01
    banksel contReg
    movwf   contReg
    goto    LED_COOL

SET_HEAT:
    ;set contReg=2 (heater is on) LATD1=1
    movlw   0x02
    banksel contReg
    movwf   contReg
    goto    LED_HOT
    
; ----------------------------
; LED labels
; ----------------------------
LED_COOL:
    ;turn on LATD2, turn off LATD1
    ; TURN OFF hotAir
    ; TURN ON coolAir
    banksel LATD
    bsf     LED1        ; RD1 = 1
    bcf     SWITCH      ; RD2 = 0
    goto    HEX_TO_DEC

LED_HOT:
    ;turn on LATD1, turn off LATD2
    ; TURN ON hotAir
    ; TURN OFF coolAir
    banksel LATD
    bsf     SWITCH      ; RD2 = 1
    bcf     LED1        ; RD1 = 0
    goto    HEX_TO_DEC

LED_OFF:
    ; Display nothing & TURN OFF all
    ;turn off both LATDs
    banksel LATD
    bcf     LED1           ; HEAT OFF
    banksel LATD
    bcf     SWITCH         ; COOL OFF
    goto    HEX_TO_DEC
    
;-----------------------------
; CONVERSION refTempReg -> REF_HUND/REF_TENS/REF_ONES
;-----------------------------
HEX_TO_DEC:
    clrf    count
    movf    refTempReg, W
    movwf   number
    movlw   100

Loop100sRef:
    incf    count, F
    subwf   number, F	    ;F=F-W 
    bc      Loop100sRef	    ; keep subtracting while Carry=1 (no borrow)
    decf    count, F
    addwf   number, F	    ; add 100 back once
    movff   count, REF_HUND ; 0x62

    clrf    count
    movlw   10		    ;Set up for tens place

Loop10sRef:
    incf    count, F
    subwf   number, F
    bc      Loop10sRef
    decf    count, F
    addwf   number, F         ; add 10 back once
    movff   count, REF_TENS   ; 0x61
    movff   number, REF_ONES  ; 0x60
;-----------------------------
;CONVERSION measTempReg -> MEA_HUND/MEA_TENS/MEA_ONES
;-----------------------------
    clrf    count
    movf    measTempReg, W
    movwf   number
    ; abs(measuredTempReg) fro negative measurement vals
    btfss   number, 7        ; if bit7 = 0, already positive
    goto    MeasPos
    comf    number, F        ; two's complement: invert
    incf    number, F        ; +1
MeasPos:
    movlw   100

Loop100sMeas:
    incf    count, F
    subwf   number, F		;F=F-W
    bc      Loop100sMeas	; keep subtracting until Carry=0 (borrow)
    decf    count, F
    addwf   number, F
    movff   count, MEA_HUND	; 0x72
    clrf    count
    movlw   10			; Set up for tenths place

Loop10sMeas:
    incf    count, F
    subwf   number, F
    bc      Loop10sMeas
    decf    count, F
    addwf   number, F
    movff   count, MEA_TENS	; 0x71
    movff   number, MEA_ONES	; 0x70

    goto    ENDPROG		; go back to your end/idle loop
   
ENDPROG:
    sleep
    bra ENDPROG 
    
  