; This is a basic template file for writing 48K Spectrum code.

;*********************************************************************
; ZX Spectrum Clock - an example on how to use interrupt mode 2 (IM 2)
;
; Print_String routine inspired from Dean Belfield's page
; http://www.breakintoprogram.co.uk/
;
; In memoriam Razvan Jigorea (1974 - 2006)
; http://jigorea.com/
;
; Revisions so far:
;
; Jun 13 2022 - Cristian Zaslo
;             - initial revision
;
;*********************************************************************


AppFilename             EQU "Clock"                   ; What we're called (for file generation)


AppFirst                EQU $8000                     ; First byte of code (uncontended memory)
IntTable                EQU $DF00
Int2Routine             EQU $E0E0




                        zeusemulate "48K","ULA+"      ; Set the model and enable ULA+


; Start planting code here. (When generating a tape file we start saving from here)

                        ORG AppFirst                 ; Start of application

AppEntry                NOP                          ; Replace these lines with your code


                        PUSH AF                      ; save registers
                        PUSH HL
                        PUSH DE
                        PUSH BC


                        LD HL, IntTable               ; fill in interrupt vector with ISR address
                        LD (HL), Int2Routine / 256
                        LD DE, IntTable + 1
                        LD BC, 256
                        LDIR                          ; end fill

                        LD A, IntTable / 256          ; load high byte interrupt table address
                        ld I, A
                        IM 2;                         ; switch to interrupt mode #2


                        POP BC                        ; restore registers
                        POP DE
                        POP HL
                        POP AF

                        RET                           ; return to BASIC
LoopInf                 JR LoopInf                    ; or alternatively carry on with background task



;=================================================================================

;  Function: Print_Char

;  Purpose:  Print a single character out to a screen address
;
;  Parameters:
;  A: Character to print
;  D: Character Y position
;  E: Character X position
;
Print_Char:             LD HL, 0x3C00           ; Character set bitmap data in ROM
                        LD B,0                  ; BC = character code
                        LD C, A
                        SLA C                   ; Multiply by 8 by shifting
                        RL B
                        SLA C
                        RL B
                        SLA C
                        RL B
                        ADD HL, BC              ; And add to HL to get first byte of character
                        CALL Get_Char_Address   ; Get screen position in DE
                        LD B,8                  ; Loop counter - 8 bytes per character
Print_Char_L1:          LD A,(HL)               ; Get the byte from the ROM into A
                        LD (DE),A               ; Stick A onto the screen
                        INC HL                  ; Goto next byte of character
                        INC D                   ; Goto next line on screen
                        DJNZ Print_Char_L1      ; Loop around whilst it is Not Zero (NZ)
                        RET

; END Function: Print_Char
;=================================================================================


;=================================================================================
; Function: Get_Char_Address:

; Purpose:  Get screen address from a character (X,Y) coordinate

; Parameters:
; D = Y character position (0-23)
; E = X character position (0-31)
; Returns screen address in DE
; Formula: Address = 4000h + (Y / 8)*800h + (Y % 8)*20h + X


Get_Char_Address:       LD A,D
                        AND %00000111  ; Y % 8
                        RRA
                        RRA
                        RRA
                        RRA            ; * 20h
                        OR E           ; + X
                        LD E,A         ; store into low byte

                        LD A,D
                        AND %00011000  ; (Y / 8) * 8h
                        OR %01000000   ; + 40h
                        LD D,A         ; store into high byte means x 100h
                        RET

; END Function: Get_Char_Address
;==================================================================================

;==================================================================================
; Function Print_String

;  Parameters
;  HL: Address of the string
;  D: Character Y position
;  E: Character X position
;  REM: string must be null terminated
;
Print_String:           LD A, (HL)              ; Get the character
                        CP 0                    ; CP with 0
                        RET Z                   ; Ret if it is zero
                        INC HL                  ; Skip to next character in string
                        CP 32                   ; CP with 32 (space character)
                        JR C, Print_String      ; If < 32, then don't ouput
                        PUSH DE                 ; Save screen coordinates
                        PUSH HL                 ; And pointer to text string
                        CALL Print_Char         ; Print the character
                        POP HL                  ; Pop pointer to text string
                        POP DE                  ; Pop screen coordinates
                        INC E                   ; Inc to the next character position on screen
                        JR Print_String         ; Loop

; END Function: Print_String
;====================================================================================

;====================================================================================
; Function: Inc_Timer

;  Parameters
;  REM: call every other second


Inc_Timer               PUSH AF                         ; save registers

                        LD A,(Seconds)                  ; increment seconds
                        INC A
                        CP A,60                         ; compare with 60
                        LD (Seconds), A                 ; store
                        JR NZ ExitIncTimer
                        XOR A                           ; clear seconds
                        LD (Seconds), A                 ; store

                        LD A,(Minutes)                  ; increment minutes
                        INC A
                        CP A,60                         ; compare witjh 60
                        LD (Minutes), A                 ; store
                        JR NZ ExitIncTimer
                        XOR A                           ; clear minutes
                        LD (Minutes), A                 ; store

                        LD A,(Hours)                    ; increment hours
                        INC A
                        CP A,24                         ; compare with 24
                        LD (Hours), A                   ; store
                        JR NZ ExitIncTimer
                        XOR A                           ; clear hours
                        LD (Hours), A

ExitIncTimer            POP AF                          ; restore registers

                        RET                             ; return

; END Function: Inc_Timer
;==================================================================================

;==================================================================================
; Function: Divideby10

;  Parameters
;  A: Divisor

;  Return
;  H: Quotient
;  L: Remainder

Divideby10              EX AF, AF'                    ; save AF'
                        PUSH AF

                        EX AF, AF'                    ; restore Divisor

                        PUSH AF                       ; save Divisor

                        LD H, -1                      ; init
                        LD L, -10                     ; init
Div_Loop                INC H;                        ; inc Quotient
                        EX AF,AF'                     ; save A
                        LD A,L                        ; add 10 to L
                        ADD A,10
                        LD L,A
                        EX AF,AF'                     ; restore A
                        SUB 10                        ; subtract 10
                        JR NC Div_Loop                ; continue if positive

                        POP AF                        ; read back Divisor
                        SUB A,L                       ; subtract L
                        LD L,A                        ; store Remainder

                        POP AF
                        EX AF, AF'
                        RET

; END Function: Divideby10
;==================================================================================

;==================================================================================
; Function: Print_Clock


Print_Clock              PUSH AF                      ; save registers
                         PUSH HL

                         ; prepare seconds to print
                         LD A,(Seconds)               ; load seconds
                         CALL Divideby10              ; divide
                         LD A,L                       ; load remainder
                         ADD A,$30                    ; add $30
                         LD (Clock+7),A               ; store result
                         LD A,H                       ; load quotient
                         ADD A,$30                    ; add $30
                         LD (Clock+6),A               ; store result

                         ; prepare minutes to print
                         LD A,(Minutes)               ; load minutes
                         CALL Divideby10              ; divide
                         LD A,L                       ; load remainder
                         ADD A,$30                    ; add $30
                         LD (Clock+4),A               ; store result
                         LD A,H                       ; load quotient
                         ADD A,$30                    ; add $30
                         LD (Clock+3),A               ; store result

                         LD A,(Hours)                 ; load hours
                         CALL Divideby10              ; divide
                         LD A,L                       ; load remainder
                         ADD A,$30                    ; add $30
                         LD (Clock+1),A               ; store result
                         LD A,H                       ; load quotient
                         ADD A,$30                    ; add $30
                         LD (Clock+0),A               ; store result

                         LD HL, Clock                 ; load address to print
                         LD D,0                       ; load Y position
                         LD E,0                       ; load X position
                         CALL Print_String            ; call print routine

                         POP HL                       ; restore registers
                         POP AF

                         RET                          ; return

; END Function: Print_Clock
;==================================================================================

;==================================================================================
; Interrupt Service Routine: Int2Routine

;  REM: called every 1/50s
                        ORG Int2Routine                 ; calling frequency 50Hz

;----------->           START OF 1/50s interrupt routine

                         PUSH          AF               ; save registers
                         PUSH          HL
                         PUSH          BC
                         PUSH          DE
                         PUSH          IX
                         PUSH          IY
                         EXX
                         EX            AF, AF'
                         PUSH          AF
                         PUSH          HL
                         PUSH          BC
                         PUSH          DE


                         LD A, (Tick50Hz)              ; load Tick50Hz counter
                         INC A                         ; inc counter
                         LD (Tick50Hz), A              ; write back
                         CP 50                         ; compare with 50
                         JR NZ Int2Exit                ; jump if not equal

                         XOR A                         ; clear counter
                         LD (Tick50Hz), A

;----------->            PLACE HERE THE 1s TASK
                         CALL Inc_Timer                ; call clock update
                         CALL Print_Clock               ; print clock
;----------->            END of 1s TASK


Int2Exit                 NOP
                         RST $38                       ; call ROM routine for keyboard access
                         POP           DE              ; restore registers
                         POP           BC
                         POP           HL
                         POP           AF
                         EX            AF, AF'
                         EXX
                         POP           IY
                         POP           IX
                         POP           DE
                         POP           BC
                         POP           HL
                         POP           AF


                         EI                           ; enable interrupts

                         RETI                         ; return from interrupt

Seconds                  DB 0
Minutes                  DB 0
Hours                    DB 0
Tick50Hz                 DB 0
Clock                    DB '0','0',':','0','0',':','0','0',0


; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *-1                         ; The last used byte's address

; Generate some useful debugging commands

                        profile AppFirst,AppLast-AppFirst+1     ; Enable profiling for all the code

; Setup the emulation registers, so Zeus can emulate this code correctly

Zeus_PC                 equ AppEntry                            ; Tell the emulator where to start
Zeus_SP                 equ $FF40                               ; Tell the emulator where to put the stack

; These generate some output files

                        ; Generate a SZX file
                        output_szx AppFilename+".szx",$0000,AppEntry    ; The szx file

                        ; If we want a fancy loader we need to load a loading screen
;                        import_bin AppFilename+".scr",$4000            ; Load a loading screen

                        ; Now, also generate a tzx file using the loader
                        output_tzx AppFilename+".tzx",AppFilename,"",AppFirst,AppLast-AppFirst,1,AppEntry ; A tzx file using the loader


