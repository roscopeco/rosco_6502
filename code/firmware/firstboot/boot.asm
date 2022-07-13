;------------------------------------------------------------
;                            ___ ___ ___ ___ 
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|    Bringup Code
;------------------------------------------------------------
; Copyright (c)2022 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Initial bringup and basic testing code for the board.
;------------------------------------------------------------
        section .data
        ORG 0

        section .text
        ORG $e000

DUA_MR1A    = $c000
DUA_MR2A    = $c000
DUA_SRA     = $c001
DUA_CSRA    = $c001
DUA_CRA     = $c002 
DUA_TBA     = $c003
DUA_ACR     = $c004
DUA_IMR     = $c005
DUA_CTUR    = $c006
DUA_CTLR    = $c007
DUA_OPR_S   = $c00e
DUA_STARTC  = $c00e
DUA_OPR_C   = $c00f
DUA_STOPC   = $c00f

start:
        cli
        cld
        lda #$ff
        txs

        ; Init DUART
        lda #$a0          ; Enable extended TX rates
        sta DUA_CRA
        lda #$80          ; Enable extended RX rates
        sta DUA_CRA
        lda #$80          ; Select bit rate set 2
        sta DUA_ACR
        lda #$88          ; Select 115k2
        sta DUA_CSRA
        lda #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
        sta DUA_MR1A
        lda #$07          ; Normal, No TX CTX/RTS, 1 stop bit
        sta DUA_MR2A
        lda #$05          ; Enable TX/RX port A
        sta DUA_CRA

        ; Do the banner
        jsr printbanner

        ; Basic banking check
        jsr bankcheck

        ; Go to flash loop
.flash:
        lda #$08          ; LED on
        sta DUA_OPR_S     
    
        ldy #$FF          ; (2 cycles)
        ldx #$FF          ; (2 cycles)
.delay:  
        dex               ; (2 cycles)
        bne .delay        ; (3 cycles in loop, 2 cycles at end)
        dey               ; (2 cycles)
        bne .delay        ; (3 cycles in loop, 2 cycles at end)

        lda #$08          ; LED off
        sta DUA_OPR_C

        ldy #$FF          ; (2 cycles)
        ldx #$FF          ; (2 cycles)
.delay2:
        dex               ; (2 cycles)
        bne .delay2       ; (3 cycles in loop, 2 cycles at end)
        dey               ; (2 cycles)
        bne .delay2       ; (3 cycles in loop, 2 cycles at end)

        bra .flash


; *******************************************************
; * Banner print
; *******************************************************
printbanner:
        ldy #$00          ; Start at first character

.loop
        ldx SZ_BANNER0,Y  ; Get character into x
        beq .done         ; If it's zero, we're done..
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .loop         ; and continue

.done
        rts

        
; *******************************************************
; * Blocking putc to DUART. Character in X
; *******************************************************
putc:
        lda DUA_SRA       ; Check TXRDY bit
        and #4
        beq putc          ; Loop if not ready (bit clear)
        stx DUA_TBA       ; else, send character
        rts
        

; *******************************************************
; * Basic test of the memory bank hardware
; *******************************************************
bankcheck:
        ldx #$00          ; Start at bank 0
.writeloop
        stx $DFFF         ; Set bank register
        stx $4000         ; Store bank num to start of bank...
        stx $BFFF         ; ... and to end also
        inx               ; Next bank...
        cpx #$10          ; ... unless we're out of banks
        beq .read         ; (go to read if so)
        bra .writeloop    ; else loop for next bank.

.read
        ldx #$00          ; Start back at bank 0
.readloop
        stx $DFFF         ; Set bank register
        cpx $4000         ; Is first byte of bank the bank num?
        bne .failed       ; ... failed if not :-(
        cpx $BFFF         ; Is last byte of bank the bank num?
        bne .failed       ; ... also failed if not :-(
        inx               ; Next bank...
        cpx #$10          ; ... unless we're out of banks
        beq .passed       ; (if so, we passed :-) )
        bra .readloop     ; else loop for next bank.

; If we reach this, the check passed!
.passed
        ldy #$00          ; Start at first character of message

.passloop
        ldx PASSED,Y      ; Get character at Y into X
        beq .done         ; If it's zero, we're done
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .passloop     ; and continue...

; If we get here, the check failed :-(
.failed
        ldy #$00          ; Start at first character of message
.failloop
        ldx FAILED,Y      ; Get character at Y into X
        beq .done         ; If it's zero, we're done
        jsr putc          ; otherwise, print it
        iny               ; next character
        bra .failloop     ; and continue...

; We're done.
.done
        rts
      
  
; *******************************************************
; * Data
; *******************************************************
SZ_BANNER0      db      $D, $A, $1B, "[1;33m"
SZ_BANNER1      db      "                           ___ ___ ___ ___ ", $D, $A
SZ_BANNER2      db      " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D, $A
SZ_BANNER3      db      "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D, $A
SZ_BANNER4      db      "|_| |___|___|___|___|_____|___|___|___|___|", $D, $A
SZ_BANNER5      db      "                    |_____|", $1B, "[1;37mBringup ", $1B, "[1;30m0.01.DEV", $1B, "[0m", $D, $A, 0
FAILED          db      "Bankcheck failed", $D, $A, 0
PASSED          db      "Bankcheck passed", $D, $A, 0

; *******************************************************
; * Vectors
; *******************************************************
        ORG $fffc

RESET           dw      start
IRQ             dw      $00E0

