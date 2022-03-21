; Controla o brilho de um LED usando duas chaves (sem usar interrupção)  
; A chave key UP (pino 2) aumenta o ciclo ativo do PWM.  
; E a chave key DOWN (pino 7) diminui o ciclo ativo do PWM. 
;
; Para evitar o efeito debounce das chaves (repique)
; foram usados varios atrasos de 100ms.
;
; o PWM foi configurado em PWM Phase Correct (freq.2KHz) 
;
;
; por Adriano S. Costa, 2022
;
; 
;
; Device: ATtiny25V, Package: 8-pin-PDIP_SOIC
;
;             ______
;          1 /      |8
; /RESET o--|       |--o VCC
; KEY UP o--|       |--o KEY DOWN
;    PB4 o--|       |--o PB1
;   GND  o--|       |--o PWM OUT
;          4|_______|5
;
; PORTB bit : 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0
; PORTB PIN :       |PB5|PB4|PB3|PB2|PB1|PB0
; PIN number:       | 1 | 3 | 2 | 7 | 6 | 5;
; 
.nolist
.include "tn25def.inc" ; define dispositivo ATtiny25
.list

;------------------------------------------------------------------------------
; Registros 
;------------------------------------------------------------------------------
; R0 a R15 -> não usado
.def temp = r16 ; registro R16 para uso geral 
; R17 a R19 -> não usado 
; R20, R21 e R22 -> usado no controle do sinal PWM 
; R31:R30 -> Z usado para ...

;------------------------------------------------------------------------------
; Portas & Porta bits
;------------------------------------------------------------------------------
.equ keyStatus = PINB ; estado das chaves 
.equ keyDown = 0b00000100 ; filtro do bit da chave down (PB2)
.equ keyUP = 0b00001000 ; filtro do bit da chave up (PB3)

;------------------------------------------------------------------------------
; Constantes ajustáveis 
;------------------------------------------------------------------------------
.equ clock=8000000 ; Define a frequencia de clock 

;------------------------------------------------------------------------------
; Constantes fixas e derivadas  
;------------------------------------------------------------------------------
; .equ ctc0clk = clock / 256 ; Define a partir do clock
 
;------------------------------------------------------------------------------
; Segmento da RAM 
;------------------------------------------------------------------------------
.dseg
.org SRAM_START
 ; sem uso de RAM para variáveis específicas nesse programa,  
 ; RAM usada apenas para a pilha
 ; label: 
 ; .byte 16 ; Reserva 16 bytes

;------------------------------------------------------------------------------
; Segmento do código
;------------------------------------------------------------------------------
.cseg
.org 000000

;------------------------------------------------------------------------------
; Vetores de interrupção
;------------------------------------------------------------------------------
rjmp main ; Reset vector
reti ; INT0
reti ; PCI0
reti ; OVF0
reti ; ERDY
reti ; ACI
reti ; OC0A
reti ; OC0B
reti ; WDT
reti ; ADCC

;------------------------------------------------------------------------------
; Rotinas de serviço de interrupção (ISR)
;------------------------------------------------------------------------------
; não usa interrupção 

;------------------------------------------------------------------------------
; Rotina principal 
;------------------------------------------------------------------------------

main:
ldi temp,Low(RAMEND) ; carrega endereço LSB do final da RAM 
out SPL,temp ; e inicializa o ponteiro da pilha 

ldi r16, 0b00000001 ; configura direção dos pinos 
out DDRB, r16 ; PB0 é saída e o restante dos pinos é entrada 

ldi r16, 0b11110010 ; configura pullups internos, exceto PB0,PB2 e PB3
out PORTB, r16 ; e ativa saída 

; Configura os limites mínimo e máximo  
; do PWM que controla a intensidade do brilho do LED 
; 256 níveis de variação do ciclo de trabalho do PWM 

; define o ciclo ativo mínimo do PWM = 5.07%  (13/256 * 100 = 5.07% ) 
.equ minPWM = 13   
; define o ciclo ativo máximo do PWM = 94.9%  (243/256 * 100 = 94.9% )
.equ maxPWM = 243 ; 

ldi r20, minPWM   ; nivel mínimo em r20
ldi r21, maxPWM   ; nível máximo em r21
mov r22, r20 ; valor corrente do PWM em r22 (inicia no nível mínimo)  

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Alguns registros do Timer/Counter0 envolvidos na configuração do sinal PWM 

; TCCR0A(0x2A) - Timer/Counter Control Register A

; Bit       |   7    |   6    |   5    |   4    | 3 | 2 |   1   |   0
; 0x2A      | COM0A1 | COM0A0 | COM0B1 | COM0B0 | - | - | WGM01 | WGM00 
; Read/Write|  R/W   |  R/W   |  R/W   |  R/W   | R | R |  R/W  |  R/W
; Int. Value|   0    |   0    |   0    |   0    | 0 | 0 |   0   |   0


;Tabela do modo de saída da comparação (modo Phase Correct PWM) :

; COM0A1|COM0A0|Descrição
;----------------------------------------------------------------------- 
;   0   |  0   | Operação normal da porta, OC0A/OC0B desconectados.
;       |      |
;   0   |  1   | Reservado 
;       |      |
;   1   |  0   | Reseta OC0A/OC0B na contagem crescente quando ocorre 
;       |      | igualdade de comparação, e seta OC0A/OC0B na contagem
;       |      | decrescente quando ocorre igualdade de comparação
;       |      |
;   1   |  1   | Seta OC0A/OC0B na contagem crescente quando ocorre 
;       |      | igualdade de comparação, e Reseta OC0A/OC0B na contagem
;       |      | decrescente quando ocorre igualdade de comparação       


;Tabela do modo de geração da forma de onda:

;                      | Modo de operação do|      | atualização | TOV Flag  
;Modo|WGM02|WGM01|WGM00| Timer/Counter      | TOP  | OCRx        | Set on
;---------------------------------------------------------------------------
; 0  |  0  |  0  |  0  | Normal             | 0xFF |   Imediata  |  MAX
; 1  |  0  |  0  |  1  | PWM, Phase Correct | 0xFF |     TOP     | BOTTOM
; 2  |  0  |  1  |  0  | CTC                | OCRA |   Imediata  |  MAX
; 3  |  0  |  1  |  1  | Fast PWM           | 0xFF |   BOTTOM    |  MAX
; 4  |  1  |  0  |  0  | Reservedo          |   -  |      -      |   -    
; 5  |  1  |  0  |  1  | PWM, Phase Correct | OCRA |     TOP     | BOTTOM
; 6  |  1  |  1  |  0  | Reservedo          |   -  |      -      |   -    
; 7  |  1  |  1  |  1  | Fast PWM           | OCRA |   BOTTOM    |  TOP

;Notes: BOTTOM = 0x00
;          MAX = 0xFF
;          TOP = 0xFF ou OCRA

; TCCR0B(0x33) - Timer/Counter Control Register B

; Bit       |   7   |   6   | 5 | 4 |   3   |   2  |   1  |   0
; 0x33      | FOC0A | FOC0B | - | - | WGM02 | CS02 | CS01 | CS00 
; Read/Write|   W   |   W   | R | R |  R/W  |  R/W |  R/W |  R/W
; Int. Value|   0   |   0   | 0 | 0 |   0   |   0  |   0  |   0


;Tabela de seleção do clock:
                      
;CS02|CS01|CS00| Descrição 
;---------------------------------------------------------------------------
;  0 |  0 |  0 | Sem clock (Timer/Counter parado) 
;  0 |  0 |  1 | clkIO (sem pré-calibrador)
;  0 |  1 |  0 | clkIO/8 (do pré-calibrador)
;  0 |  1 |  1 | clkIO/64 (do pré-calibrador)
;  1 |  0 |  0 | clkIO/256 (do pré-calibrador) 
;  1 |  0 |  1 | clkIO/1024 (do pré-calibrador)
;  1 |  1 |  0 | clock externo no pino T0 ativado na borda de descida. 
;  1 |  1 |  1 | clock externo no pino T0 ativado na borda de subida. 


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------


; Minha configuração do registro TCCR0A (0x2A)

;  Bit |  7   |  6   |  5   |  4   | 3 | 2 |  1  |  0
;      |COM0A1|COM0A0|COM0B1|COM0B0| - | - |WGM01|WGM00 
;      |  1   |  0   |  0   |  0   | 0 | 0 |  0  |  1


; Reseta OC0A/OC0B na contagem crescente quando ocorre 
; igualdade de comparação entre o valor OCR0A e TCNT0, 
; e seta OC0A/OC0B na contagem
; decrescente quando ocorre igualdade de comparação nos 
; mesmos registros. 

; Produz um sinal PWM no modo Phase Correct PWM
; no pino OC0A (PB0)

ldi r16, 0b10000001
out TCCR0A, r16  


; Minha configuração do registro TCCR0B (0x33)
;
; Bit  |  7  |  6  | 5 | 4 |  3  |  2 |  1 |  0
;      |FOC0A|FOC0B| - | - |WGM02|CS02|CS01|CS00 
;      |  0  |  0  | 0 | 0 |  0  |  0 |  1 |  0

; seleciona o pré-calibrador clkIO/8
; frequência PWM = 2KHz
ldi r16, 0b00000010 
out TCCR0B, r16


;  inicia PWM em 5%
out OCR0A, r22 ; carrega o registro OCR0A com o valor corrente 

;------------------------------------------------------------------------------
; Rotina circular 
;------------------------------------------------------------------------------

; funções para determinar o estado das chaves e as formas de controle que as 
; chaves exercem sobre o brilho do LED  

; verifica o estado das chaves (PB2 -> down / PB3 -> up)
keyCheck:
; primeiro verifica o estado da chave up
in r16, keyStatus ; estado dos pinos em r16 
andi r16,keyUP ;  filtra o bit da chave up (PB3)

cpi r16, 0 ; e compara com zero 
brne k0 ; é zero? NÂO -> chave up não foi pressionada, 
; passa para a chave down
; SIM -> chave up pressionada, então 
; salta para função que aumenta o brilho do LED
rjmp k2 

; verifica o estado da chave down
k0:
in r16, keyStatus ; estado dos pino em r16 
andi r16, keyDown ; filtra o bit da chave down (PB2)

cpi r16, 0 ; e compara com zero 
brne keyCheck; ; é zero? NÂO -> chave down não foi pressionada, 
; e a chave up também não , continua a verificação do estado das chaves.
; SIM -> chave down pressionada, então  
; diminui o prilho do LED nos comando seguintes
k1:
; primeiro decrementa o valor do brilho do LED uma vez e 
; depois verifica se a chave down continua pressionada. 
; A chave foi solta? SIM -> Apenas retorna para a verificação das chaves. 
; A chave continua pressionada? SIM -> Após cada intervalo de
; tempo (tempo de latência) repete o decremento do valor do brilho 
; até que a chave seja solta.
rcall downLED

; tempo de latência da repetição 'downLED'
rcall wait100ms
rcall wait100ms
rcall wait100ms

in r16, keyStatus ; estado dos pino em r16 
andi r16, keyDown ; filtra o bit da chave down (PB2)

cpi r16, 0 ; compara com zero 
breq k1 ; é zero? SIM -> chave down continua pressionada,   
; repete a função 'downLED' 

; NÃO -> a chave foi solta, espera mais 100 ms 
rcall wait100ms 

; e recomeça a verificação do estado da chave 
rjmp keyCheck 


; chave up pressionada,  aumenta o brilho do LED
k2:
; primeiro incrementa o valor do brilho do LED uma vez e 
; depois verifica se a chave up continua pressionada. 
; A chave foi solta? SIM -> Apenas retorna para a verificação das chaves. 
; A chave continua pressionada? SIM -> Após cada intervalo de
; tempo (tempo de latência) repete o incremento do valor do brilho 
; até que a chave seja solta.
rcall upLED

; tempo de latência da repetição 'upLED'
rcall wait100ms
rcall wait100ms
rcall wait100ms


in r16, KeyStatus ; estado dos pino em r16 
andi r16, keyUP ; filtra o bit da chave up (PB3)

cpi r16, 0 ; compara com zero 
breq k2 ; é zero? SIM -> chave up continua pressionada,   
; então repete a função 'upLED' 

; NÃO -> a chave foi solta, espera mais 100 ms 
rcall wait100ms 

; e recomeça a verificação do estado das chaves 
rjmp keyCheck 



; funções para diminuir ou aumentar o ciclo ativo do pulso PWM até o limite 
; pré-determinado 

; diminui o ciclo ativo do pulso PWM
downLED:
cp r22, r20 ; comapara o valor atual do PWM com o limite mínimo
brbc 1, menos ; chegou no limite? NÂO -> decrementa o valor.  
; SIM -> mantém o valor no limite mínimo e retorna.   
ret 

menos:
dec r22 ; decrementa o valor atual
out OCR0A, r22 ; e muda o ciclo ativo do PWM 
ret 

; aumenta o ciclo ativo do pulso PWM 
upLED:
cp r22, r21 ; comapara o valor atual do PWM com o limite máximo 
brbc 1, mais ; chegou no limite? NÂO -> incrementa o valor.  
; SIM -> mantém o valor no limite máximo e retorna. 
ret 

mais:
inc r22 ; incrementa o valor atual
out OCR0A, r22 ; e muda o ciclo ativo do PWM 
ret 

; função para gerar um atraso de 100 ms
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

