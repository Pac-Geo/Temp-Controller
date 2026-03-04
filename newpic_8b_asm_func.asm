; FileName: TempController
; Author: Geovani Palomec
; Date: 3/7/26
; MPLAB Version: v6.30
;------------------------------------------------------------------------------
; Program Vervsion: V1
; Patch notes of V; NA
; Purpose: MEasure, Set and adjust temp accordingly.
; Inputs: Temperature readings
; Outputs: PortD
; Instructions:	DO NOT TOUCH
; Dependencies:	<xc.inc>
    
processor 18F47K42
#include <xc.inc>
    
;----------------
; PROGRAM INPUTS
;----------------
;The DEFINE directive is used to create macros or symbolic names for values.
;It is more flexible and can be used to define complex expressions or sequences of instructions.
;It is processed by the preprocessor before the assembly begins.

#define  measuredTempInput 	45 ; this is the input value
#define  refTempInput 		25 ; this is the input value

;---------------------
; Definitions
;---------------------
#define SWITCH    LATD,2  
#define LED0      PORTD,0
#define LED1	   PORTD,1
    
 
;---------------------
; Program Constants
;---------------------
; The EQU (Equals) directive is used to assign a constant value to a symbolic name or label.
; It is simpler and is typically used for straightforward assignments.
;It directly substitutes the defined value into the code during the assembly process.
    
REG10   equ     10h   ; in HEX
REG11   equ     11h
REG01   equ     1h

;----------------------------
; Program registers
;----------------------------
contReg      equ 20h
refTempReg   equ 21h
measTempReg  equ 22h
count        equ 30h
number       equ 31h

; Required BCD output registers
REF_ONES     equ 60h
REF_TENS     equ 61h
REF_HUND     equ 62h
MEA_ONES     equ 70h
MEA_TENS     equ 71h
MEA_HUND     equ 72h

;----------------------------
; Reset Vector
;----------------------------
    org 0x000
    goto main

;----------------------------
; Main
;----------------------------
main:
    ; PORTD output setup
    banksel TRISD
    clrf    TRISD
    banksel PORTD
    clrf    PORTD

    ; Step 2: arbitrary values required by assignment
    movlw   0x05
    movwf   refTempReg
    movlw   0x06
    movwf   measTempReg

;----------------------------
; R1-R3: Compare measured vs ref
; (Image-style: use BZ / BC)
;----------------------------
    movf    refTempReg, W
    subwf   measTempReg, W     ; W = meas - ref

    bz      SET_EQUAL          ; if meas == ref
    bc      SET_HOT            ; if meas > ref (since not equal, and carry=1 => meas>=ref)
    goto    SET_COOL           ; else meas < ref

SET_EQUAL:
    clrf    contReg
    goto    LED_OFF

SET_HOT:
    movlw   0x02
    movwf   contReg
    goto    LED_HOT

SET_COOL:
    movlw   0x01
    movwf   contReg
    goto    LED_COOL

;----------------------------
; Step 3: LED actions (PORTD)
;----------------------------
LED_HOT:
    ; Turn ON hotAir (LED1), OFF coolAir (LED0)
    banksel PORTD
    bcf     PORTD,0
    bsf     PORTD,1
    goto    HEX_TO_BCD

LED_COOL:
    ; Turn ON coolAir (LED0), OFF hotAir (LED1)
    banksel PORTD
    bsf     PORTD,0
    bcf     PORTD,1
    goto    HEX_TO_BCD

LED_OFF:
    ; Turn OFF all
    banksel PORTD
    bcf     PORTD,0
    bcf     PORTD,1
    goto    HEX_TO_BCD

;----------------------------
; HEX -> DEC (BCD digits) using subtraction method (matches image)
; Store:
;   ref  -> REG60-62
;   meas -> REG70-72
;----------------------------
HEX_TO_BCD:

; -------- REF TEMP: refTempInput -> 0x60..0x62 --------
    clrf    count
    movlw   refTempInput
    movwf   number
    movlw   100

Loop100sRef:
    incf    count, F
    subwf   number, F
    bc      Loop100sRef
    decf    count, F
    addwf   number, F
    movff   count, REF_HUND

    clrf    count
    movlw   10

Loop10sRef:
    incf    count, F
    subwf   number, F
    bc      Loop10sRef
    decf    count, F
    addwf   number, F
    movff   count, REF_TENS
    movff   number, REF_ONES

; -------- MEASURED TEMP: measuredTempInput -> 0x70..0x72 --------
    clrf    count
    movlw   measuredTempInput
    movwf   number
    movlw   100

Loop100sMeas:
    incf    count, F
    subwf   number, F
    bc      Loop100sMeas
    decf    count, F
    addwf   number, F
    movff   count, MEA_HUND

    clrf    count
    movlw   10

Loop10sMeas:
    incf    count, F
    subwf   number, F
    bc      Loop10sMeas
    decf    count, F
    addwf   number, F
    movff   count, MEA_TENS
    movff   number, MEA_ONES

    goto    $       ; stop here forever