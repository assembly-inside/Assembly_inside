; Controla o brilho de um LED usando duas chaves (sem usar interrupção)  
; versão sem comentários 
; por Adriano S. Costa, 2022

.nolist
.include "tn25def.inc" 
.list

.def temp = r16
.equ keyStatus = PINB 
.equ keyDown = 0b00000100
.equ keyUP = 0b00001000 

.dseg
.org SRAM_START

.cseg
.org 000000

rjmp main 
reti ; INT0
reti ; PCI0
reti ; OVF0
reti ; ERDY
reti ; ACI
reti ; OC0A
reti ; OC0B
reti ; WDT
reti ; ADCC

main:
ldi temp,Low(RAMEND) 
out SPL,temp 

ldi r16, 0b00000001 
out DDRB, r16 ; PB0

ldi r16, 0b11110010 
out PORTB, r16 

.equ minPWM = 13   
.equ maxPWM = 243  

ldi r20, minPWM   
ldi r21, maxPWM   
mov r22, r20 

ldi r16, 0b10000001
out TCCR0A, r16  

ldi r16, 0b00000010 
out TCCR0B, r16

out OCR0A, r22

keyCheck:
in r16, keyStatus
andi r16,keyUP
cpi r16, 0 
brne k0 
rjmp k2 

k0:
in r16, keyStatus 
andi r16, keyDown 
cpi r16, 0 
brne keyCheck

k1:
rcall downLED
rcall wait100ms
rcall wait100ms
rcall wait100ms
in r16, keyStatus 
andi r16, keyDown 
cpi r16, 0 
breq k1 
rcall wait100ms 
rjmp keyCheck 

k2:
rcall upLED
rcall wait100ms
rcall wait100ms
rcall wait100ms
in r16, KeyStatus 
andi r16, keyUP 
cpi r16, 0
breq k2 
rcall wait100ms 
rjmp keyCheck 

downLED:
cp r22, r20 
brbc 1, menos 
ret 
menos:
dec r22 
out OCR0A, r22 
ret 

upLED:
cp r22, r21 
brbc 1, mais
ret 
mais:
inc r22 
out OCR0A, r22 
ret 

wait100ms: 
; Assembly code auto-generated
; by utility from Bret Mulvey
; Delay 100 000 cycles
; 100ms at 1MHz

    ldi  r18, 130
    ldi  r19, 222
L1: dec  r19
    brne L1
    dec  r18
    brne L1
    nop
	ret

; End of source code
