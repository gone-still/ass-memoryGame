
;
; memoryGame.asm
;
; Created: 30/10/2021 11:59:31 PM
; Author : Rich Acevedo
; Atmel-based Assembly program that implements
; a basic memory game for the ATMEGA328P @ 1.2 MHz

; Connections:
; Port D 0-3 (Outputs): Colored LED
; Port D 6 (Output): Green LED (Pattern Match)
; Port D 7 (Output): Red LED (Pattern Mismatch)
; Port B 0 (Input): Start Button
; Port B 1-4 (Input): Push Button matching colored LED
; Port B 5-7 (Input): ATMEGA323P Misc Connections

; Register definitions:

.def tempReg = r16		; Temp Registers
.def buttonReg = r17	; Button Register for every push button (start/LEDs)
.def timerValue = r18	; Value of Timer 0
.def maskedValue = r19	; Result of the random counter, masked to 2 bits
.def ledPointer = r20	; Register that holds the address of the LED pattern
.def currentLed = r21	; Current displayed LED pattern (4-bit)
.def loopCounter = r22	; Loop counter for keeping track of logical right shifts
.def currentCount = r23	; Counter that counts memory writes
.def prevReg = r24		; Register that holds previos input button state

; Set Constants

.equ ledTableAddress = 0x0100 	; random number 2 led
.equ ledOnTable = 0x0104 		; store led patterns

.equ zero = 0x00				; 0x00 constant
.equ one = 0x01					; 0x01 constant

.equ maskValue = 0b0000_0011	; Mask value for random number generator

; Input port config:
ldi tempReg, zero
out ddrb, tempReg
; Output port config:
ldi tempReg, 0b1100_1111
out ddrd, tempReg

; create Led table:
ldi XL, low(ledTableAddress)
ldi XH, high(ledTableAddress)

; push led values
ldi tempReg, 0b0000_0001
st X+, tempReg; first led

ldi tempReg, 0b0000_0010
st X+, tempReg ; second led

ldi tempReg, 0b0000_0100
st X+, tempReg ; third led

ldi tempReg, 0b0000_1000
st X+, tempReg ; fourth led

; reset pointer:
ldi XL, low(ledTableAddress)
ldi XH, high(ledTableAddress)

; reset led pointer:
ldi ledPointer, zero
; reset current led reg:
ldi currentLed, zero
; reset current count:
ldi currentCount, zero
; reset prevReg:
ldi prevReg, 0xFF

; Configure Timer:
; Timer, prescaler of 1024
ldi tempReg, 0b0000_0101
out tccr0b, tempReg

; Load initial timer value
ldi r17, zero
out tcnt0, r17
 
; wait input:
waitStart:  

	; read button:
	nop
	nop
	in buttonReg, pinb
	
	; isolate enter bit:
	ldi tempReg, 0b0000_0001
	and buttonReg, tempReg

	; compare if enter pushed:
	cpi buttonReg, 0b0000_0001
	brne waitStart

getRandomNumber:

	; read timer:
	;ldi timerValue, 0x01
	in timerValue, TCNT0
	out portd, timerValue

	; clear flag bit by writing a one (1):
	sbi TIFR0, TOV0 
 
	; reset timer:
	ldi tempReg, zero
	out tcnt0, tempReg

createPattern:

	; mask timer value:
	ldi tempReg, maskValue
	; get the two least significant bits (00-11)
	and tempReg, timerValue

	mov maskedValue, tempReg
	
	; load default pattern word:
	ldi tempReg, 0b0000_0001
	
	; set loopCounter:
	ldi loopCounter, 0x00
	
patternLoop:	

	; This loop right-shifts the constant 0x01
	; based on the random number, to create a
	; LED pattern:
	
	; Loop control, compare number of shifts:
	cp loopCounter, maskedValue
	breq storePattern
	
	; If word must be shifted, shift it 
	; one bit to the right:
	lsl tempReg
	; one shift occoured:
	inc loopCounter
	; let's see if we need more shifts:
	rjmp patternLoop	

storePattern:

	; set random led:
	mov currentLed, tempReg

	; load led on table base address:
	ldi XL, low(ledOnTable) ; low
	ldi XH, high(ledOnTable) ; high

	; add base address + offset
	ldi tempReg, zero
	add XL, ledPointer
	adc XH, tempReg

	; store current led on:
	st X, currentLed

	; increase totalLeds
	inc ledPointer
	; inc totalLeds

	; reset led table base address:
	ldi XL, low(ledOnTable) ; low
	ldi XH, high(ledOnTable) ; high

turnOnLed:

	; get led from led on table:
	ld currentLed, X+

	; turn on led:
	out portd, currentLed
	
	; delay call:
	rcall delay500ms
	rcall delay500ms
	
	; turn off led
	ldi tempReg, zero
	out portd, tempReg

	; delay call:
	rcall delay500ms
	rcall delay500ms

	; increase counter:
	inc currentCount

	; compare with total leds in pattern:
	cp currentCount, ledPointer
	brne turnOnLed	

	; reset led table base address:
	ldi XL, low(ledOnTable) ; low
	ldi XH, high(ledOnTable) ; high	
	
	; reset counter:
	ldi currentCount, zero 

waitInput:

	nop
	nop
	nop

	; stores button previous value:
	ldi tempReg, 0b1111_1110
	and tempReg, buttonReg

	mov prevReg, tempReg

	; read button
	in buttonReg, pinb
		
	; isolate efective bits:
	ldi tempReg, 0b0001_1111
	and buttonReg, tempReg

	; shift to the right 1 place:
	; lsr buttonReg
	ldi tempReg, 0b1111_1110
	and tempReg, buttonReg

	mov buttonReg, tempReg

	; compare if pushed:		
	cpi buttonReg, zero
	breq waitInput

	;second comparison (prevReg = 0)
	cpi prevReg, 0x00
	brne waitInput

compareInput:

	; shift word to right 1 pos
	lsr buttonReg

	; get led from led on table:
	ld currentLed, X+
	
	out portd, buttonReg
	
	; wait 1 sec:
	rcall delay500ms
	rcall delay500ms 
	
	; turn off leds:
	ldi tempReg, zero
	out portd, tempReg
	

	; compare value in button vs current led on:
	cp buttonReg, currentLed
	breq numbersMatch

	; numbers do not match:
	ldi tempReg, zero
	out portd, tempReg 
	rjmp resetGame

numbersMatch:
		
	; reset buttonReg
	ldi buttonReg, 0xFF

	; increase correct matches counter:
	inc currentCount

	; compare with total leds in pattern:
	cp currentCount, ledPointer
	brne waitInput
	
	; turn on match led:
	ldi tempReg, 0b0100_0000
	out portd, tempReg 
		
	; wait 1 sec:
	rcall delay500ms
	rcall delay500ms 

	; turn off match led:
	ldi tempReg, zero
	out portd, tempReg
	
	rcall delay500ms
	rcall delay500ms 

	; clear led count:
	ldi currentCount, zero

	; create new pattern:
	rjmp getRandomNumber


resetGame:

	; turn on reset led:
	ldi tempReg, 0b1000_0000
	out portd, tempReg 
		
	; wait 1 sec:
	rcall delay500ms
	rcall delay500ms 

	; turn off reset led:
	ldi tempReg, 0b0000_0000
	out portd, tempReg 

	; turn off match led:
	ldi tempReg, zero
	out portc, tempReg

	ldi XL, low(ledTableAddress)
	ldi XH, high(ledTableAddress)

	; turn off led:
	ldi tempReg, zero
	out portd, tempReg 

	; reset led pointer:
	ldi ledPointer, zero
	; reset current led reg:
	ldi currentLed, zero
	; reset total Leds limit:
	;ldi totalLeds, zero
	; reset current count:
	ldi currentCount, zero
	; reset prevReg:
	ldi prevReg, zero	
	; reset buttonReg
	ldi buttonReg, 0xFF

	; back to start:
	rjmp waitStart



; 500 ms subroutine:
delay500ms:

	ldi r24, 0x60 ; low
	ldi r25, 0xEA ; high

	loop:
		nop
		nop
		nop
		nop
		nop
		nop

		sbiw r25:r24, 1
		brne loop

	ret
	