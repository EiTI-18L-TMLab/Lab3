;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------



;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
RESET:
        MOV.W   #__STACK_END,SP        ; set up stack
MAIN:
	MOV.B #0FFh, &P2DIR


        MOV.W   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer
        MOV.B   #0FFh, &P4DIR
        MOV.B   #0FFh, &P4OUT
        MOV.B   #000h, &P1IFG
        MOV.B   #060h, &P1IE    ; aktywacja przerwan od CLK i LD
        MOV.B	#060h, &P1IES

	MOV.B &P3IN, R4 	; inicjacja wartosci licznika
	MOV.B R4, &P4OUT	; odswiezenie licznika
	MOV #002h, R6 	        ; ilosc cykli debounce
	EINT                    ; globalna aktywacja przerwan
	MOV R6, R5 	        ; ustawienie licznika debounce
	BIC #0FFh, R7 	        ; wybrana obsluga zbocza opadajacego, main sygnalizuje ukonczenie zadan

    BIS #GIE+CPUOFF,SR ; aktywacja LPM3 - program zatrzymuje sie w tym miejscu
MAIN_LOOP: 		        ; poczatek glównej petli
    BIC #02h, R7
    DINT
	; poczatek obslugi licznika
        BIT #01h, R7
	JNZ LOOP_POSITIVE       ; wybranie obslugi konkretnego zbocza
LOOP_NEGATIVE:	                ; obsluga zbocza opadajacego
	BIT.B #040h, &P1IN	; stan przycisku CLK
	JZ IF_1
	MOV R6, R5 	        ; jesli przycisk niewcisniety, zaladuj licznik debounce
IF_1:
	JNZ IF_2
	DEC R5 		        ; jesli przycisk wcisniety, dekrementuj licznik debounce
IF_2:
	CMP #0, R5 		; czy licznik debounce równy zero
	JZ IF_2_CONTINUE        ; jesli licznik debounce zerowy, dalsza obsluga
    BIS #02h, R7            ; sygnalizacja pracy w toku
	JMP COUNTER_END
IF_2_CONTINUE:
	DEC R4		        ; wykryto poprawne zbocze opadajace, akcja licznika
	;DINT			; sekcja krytyczna
	MOV.B R4, &P4OUT	; odswiezenie LED
	;EINT			; koniec sekcji krytycznej
	BIS #01h, R7            ; wybranie obslugi zbocza narastajacego
        BIC.B #040h, &P1IE      ; wylaczenie przerwania od CLK(P1.6)
        BIC.B #040h, &P1IES     ; wybranie zbocza narastajacego
        BIC.B #040h, &P1IFG     ; wyzerowanie zadania przerwania od CLK
        BIS.B #040h, &P1IE      ; wlaczenie przerwania od CLK
	JMP COUNTER_END         ; skok na koniec obslugi licznika
LOOP_POSITIVE:	                ; obsluga zbocza narastajacego
	BIT.B #040h, &P1IN	; stan przycisku CLK
	JNZ IF_3
	MOV R6, R5 	        ; jesli przycisk niewcisniety, zaladuj licznik debounce
IF_3:
	JZ IF_4
	DEC R5		        ; jesli przycisk niewcisniety, dekrementuj licznik debounce
IF_4:
	CMP #0, R5	        ; odswiezenie stanu flag
	JZ IF_4_CONTINUE        ; jesli licznik debounce zerowy, dalsza obsluga
        BIS #02h, R7            ; sygnalizacja pracy w toku
	JMP COUNTER_END
IF_4_CONTINUE:
	BIC #01h, R7            ; wybranie obslugi zbocza opadajacego
        BIC.B #040h, &P1IE      ; wylaczenie przerwania od CLK(P1.6)
        BIS.B #040h, &P1IES     ; wybranie zbocza opadajacego
        BIC.B #040h, &P1IFG     ; wyzerowanie zadania przerwania od CLK
        BIS.B #040h, &P1IE      ; wlaczenie przerwania od CLK
COUNTER_END:	; koniec obslugi licznika
		EINT
        ; dalsze operacje...

        ; jesli zadna operacja nie zglosila pracy w toku przejdz w tryb uspienia
        BIT #02h, R7
        JNZ MAIN_LOOP

        MOV.B P1IES, &P2OUT
        BIS #GIE+CPUOFF,SR ; aktywacja LPM3 - program zatrzymuje sie w tym miejscu
        MOV.B &P2IN, R15
        INC R15
        ;BIS #GIE, SR ; NADMIAROWE?
        JMP MAIN_LOOP ; powrót do poczatku glównej petli

P1_INT_VECTOR:                          ; procedura obslugi przerwania P1
        BIT.B #020h, &P1IFG             ; sprawdzenie czy aktywne jest zadanie przerwania lub niski stan na LD
        JNZ P1_INT_VEC_LOAD
        BIT.B #020h, &P1IN      ;
        JNZ P1_INT_VEC_LOAD_DONE
P1_INT_VEC_LOAD:                        ; ciagle ladowanie gdy niski stan LD
        BIC.B #020h, P1IFG              ; zgaszenie flagi przerwania od LD(P1.5)
		MOV.B &P3IN, R4 	        ; zaladowanie nowej wartosci licznika
		MOV.B R4, &P4OUT	        ; odswiezenie wyswietlania
        JMP P1_INT_VECTOR
P1_INT_VEC_LOAD_DONE:
        BIT.B #040h, &P1IFG             ; sprawdzenie przerwania od CLK(P1.6)
        JZ P1_INT_VEC_CLK_DONE
        BIC.B #040h, &P1IE              ; interesuje nas tylko pierwsze przerwanie od CLK
        BIC.B #040h, &P1IFG             ; zgaszenie flagi przerwania od CLK
        BIC #CPUOFF+SCG1+SCG0,0(SP)     ; powrót z przerwania ze zmienionym SR
P1_INT_VEC_CLK_DONE:
        RETI


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack

;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET

            .sect ".int04"
            .short P1_INT_VECTOR
            
