; Project: Password based Smart lock System

.include "m328Pdef.inc"

.def temp       = r16
.def counter    = r18
.def userID     = r19

.dseg
.org 0x0100
CURRENT_PASS: .byte 4

.cseg
.org 0x0000
    rjmp RESET

RESET:
    ldi temp, low(RAMEND)
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp

    ; Ports Setup
    ldi temp, 0xFF
    out DDRC, temp
    ldi temp, 0b11101100
    out DDRD, temp
    ldi temp, 0b00000011
    out DDRB, temp
    ldi temp, 0b00011100
    out PORTB, temp

    ; Servo Init
    ldi temp, 8           ; pwm signal
    out OCR0B, temp
    ldi temp, (1<<WGM00) | (1<<WGM01) | (1<<COM0B1) | (1<<CS02) | (1<<CS00)
    out TCCR0A, temp
    ldi temp, (1<<CS02) | (1<<CS00)
    out TCCR0B, temp

LCD_STARTUP:
    call LCD_INIT


; Main Menu

MAIN_MENU:
    call LCD_CLEAR
    ldi ZL, low(MSG_MENU1*2)
    ldi ZH, high(MSG_MENU1*2)
    call LCD_STR
    call LCD_L2
    ldi ZL, low(MSG_MENU2*2)
    ldi ZH, high(MSG_MENU2*2)
    call LCD_STR

WAIT_KEY_MAIN: ;checking if # pressed
    call GET_KEY
    cpi r24, '#'
    brne NOT_HASH_MAIN
    jmp CLOSE_LOGIC
NOT_HASH_MAIN: ; checking if 1 pressed
    cpi r24, '1'
    brne NOT_1_MAIN
    jmp LOGIN_SEQ
NOT_1_MAIN: ; checking if 2 pressed
    cpi r24, '2'
    brne NOT_2_MAIN
    jmp ADMIN_AUTH_SEQ
NOT_2_MAIN: ; no valid key pressed
    rjmp WAIT_KEY_MAIN

CLOSE_LOGIC: ; closing door
    ldi temp, 8
    out OCR0B, temp
    cbi PORTD, 2
    jmp MAIN_MENU


; LOGIN Sequence

LOGIN_SEQ:
    ldi r17, 0      ; Address 0 holds user count
    ldi r18, 0
    call EEPROM_READ
    tst temp
    brne LOGIN_PROCEED

    ; No users registered logic
    call LCD_CLEAR
    ldi ZL, low(MSG_EMPTY*2)
    ldi ZH, high(MSG_EMPTY*2)
    call LCD_STR
    call DELAY_2S
    jmp MAIN_MENU

LOGIN_PROCEED:
    call LCD_CLEAR
    ldi ZL, low(MSG_GET_ID*2)
    ldi ZH, high(MSG_GET_ID*2)
    call LCD_STR
    call GET_KEY

    cpi r24, '*'   ; check if back button pressed (*)
    brne LP_NOT_BACK
    jmp MAIN_MENU
LP_NOT_BACK:
    cpi r24, '#'    ; check if door close button pressed (#)
    brne LP_NOT_CLOSE
    jmp CLOSE_LOGIC
LP_NOT_CLOSE:
    mov userID, r24
    call LCD_DATA

    ; ID Validation
    mov r20, userID
    subi r20, '1'
    lsl r20
    lsl r20
    inc r20
    mov r17, r20
    ldi r18, 0
    call EEPROM_READ
    cpi temp, 0xFF
    brne ASK_PASS_LOGIN

    ; Print no such user
    call LCD_L2
    ldi ZL, low(MSG_NO_USER*2)
    ldi ZH, high(MSG_NO_USER*2)
    call LCD_STR
    call DELAY_2S
    jmp MAIN_MENU

ASK_PASS_LOGIN:
    call LCD_L2
    ldi ZL, low(MSG_ENTER*2)
    ldi ZH, high(MSG_ENTER*2)
    call LCD_STR
    call INPUT_PASS

    cpi r24, 0xFF
    brne LP_NOT_BACK2
    jmp MAIN_MENU
LP_NOT_BACK2:
    cpi r24, 0xFE
    brne LP_NOT_CLOSE2
    jmp CLOSE_LOGIC
LP_NOT_CLOSE2:

    ; Password Verify
    mov r20, userID
    subi r20, '1'
    lsl r20
    lsl r20
    inc r20
    mov r17, r20
    ldi r18, 0
    ldi ZL, low(CURRENT_PASS)
    ldi ZH, high(CURRENT_PASS)
    ldi counter, 4
VP_CHECK:
    call EEPROM_READ
    ld r22, Z+
    cp temp, r22
    breq VP_OK
    jmp LOGIN_FAIL
VP_OK:
    inc r17
    dec counter
    brne VP_CHECK

    call LCD_CLEAR
    ldi ZL, low(MSG_OK*2)
    ldi ZH, high(MSG_OK*2)
    call LCD_STR
    sbi PORTD, 2        ; Green LED ON for 2 sec
    ldi temp, 23
    out OCR0B, temp
    call DELAY_2S
    cbi PORTD, 2
    jmp MAIN_MENU

LOGIN_FAIL:
    call LCD_CLEAR
    ldi ZL, low(MSG_FAIL*2)
    ldi ZH, high(MSG_FAIL*2)
    call LCD_STR
    sbi PORTD, 3        ; Red LED ON for 2 sec
    call DELAY_2S
    cbi PORTD, 3
    jmp MAIN_MENU


; ADMIN Logic

ADMIN_AUTH_SEQ:
    call LCD_CLEAR
    ldi ZL, low(MSG_SYS_REQ*2)
    ldi ZH, high(MSG_SYS_REQ*2)
    call LCD_STR
    call LCD_L2
    call INPUT_PASS

    cpi r24, 0xFF
    brne AA_NOT_BACK
    jmp MAIN_MENU
AA_NOT_BACK:
    ;chexk if the admin password is correct
    ldi ZL, low(CURRENT_PASS)
    ldi ZH, high(CURRENT_PASS)
    ld r20, Z+
    cpi r20, '1'
    brne AF_L
    ld r20, Z+
    cpi r20, '2'
    brne AF_L
    ld r20, Z+
    cpi r20, '3'
    brne AF_L
    ld r20, Z+
    cpi r20, '4'
    brne AF_L
    jmp ADMIN_MENU
AF_L: jmp LOGIN_FAIL

ADMIN_MENU:
    call LCD_CLEAR
    ldi ZL, low(MSG_ADM_M1*2)
    ldi ZH, high(MSG_ADM_M1*2)
    call LCD_STR
    call LCD_L2
    ldi ZL, low(MSG_ADM_M2_EXT*2)
    ldi ZH, high(MSG_ADM_M2_EXT*2)
    call LCD_STR

ADMIN_WAIT:
    call GET_KEY
    cpi r24, '1'
    breq JMP_REG
    cpi r24, '2'
    breq JMP_DEL
    cpi r24, '9'
    breq JMP_RESET
    cpi r24, '*'
    breq JMP_MAIN
    cpi r24, '#'
    breq JMP_CLOSE
    rjmp ADMIN_WAIT

JMP_REG: jmp REGISTER_SEQ
JMP_DEL: jmp DELETE_SEQ
JMP_RESET: jmp SYSTEM_RESET_SEQ
JMP_MAIN: jmp MAIN_MENU
JMP_CLOSE: jmp CLOSE_LOGIC

SYSTEM_RESET_SEQ:
    call LCD_CLEAR
    ldi ZL, low(MSG_RESETTING*2)
    ldi ZH, high(MSG_RESETTING*2)
    call LCD_STR
    ldi r17, 0
    ldi r18, 0
    ldi temp, 0
    call EEPROM_WRITE
    ldi counter, 40
    ldi r17, 1
RS_L: ldi temp, 0xFF
    call EEPROM_WRITE
    inc r17
    dec counter
    brne RS_L
    call DELAY_2S
    jmp MAIN_MENU

REGISTER_SEQ:
    ldi r17, 0
    ldi r18, 0
    call EEPROM_READ
    mov r22, temp
    inc r22
    call LCD_CLEAR
    ldi ZL, low(MSG_ID_ASSIGN*2)
    ldi ZH, high(MSG_ID_ASSIGN*2)
    call LCD_STR
    mov r24, r22
    subi r24, -'0'
    call LCD_DATA

    call LCD_L2
    ldi ZL, low(MSG_ENTER*2)
    ldi ZH, high(MSG_ENTER*2)
    call LCD_STR
    call INPUT_PASS
    cpi r24, 0xFF
    brne REG_CONT
    jmp ADMIN_MENU
REG_CONT:

    dec r22
    mov r17, r22
    lsl r17
    lsl r17
    inc r17
    ldi ZL, low(CURRENT_PASS)
    ldi ZH, high(CURRENT_PASS)
    ldi counter, 4
RG_S: ld temp, Z+
    call EEPROM_WRITE
    inc r17
    dec counter
    brne RG_S
    inc r22
    ldi r17, 0
    ldi r18, 0
    mov temp, r22
    call EEPROM_WRITE
    call LCD_CLEAR
    ldi ZL, low(MSG_SAVED*2)
    ldi ZH, high(MSG_SAVED*2)
    call LCD_STR
    call DELAY_2S
    jmp ADMIN_MENU

DELETE_SEQ:
    ;check for empty system in Delete
    ldi r17, 0
    ldi r18, 0
    call EEPROM_READ
    tst temp
    brne DELETE_PROCEED
    call LCD_CLEAR
    ldi ZL, low(MSG_EMPTY*2)
    ldi ZH, high(MSG_EMPTY*2)
    call LCD_STR
    call DELAY_2S
    jmp ADMIN_MENU

DELETE_PROCEED:
    call LCD_CLEAR
    ldi ZL, low(MSG_DEL_ID*2)
    ldi ZH, high(MSG_DEL_ID*2)
    call LCD_STR
    call GET_KEY
    cpi r24, '*'
    brne DEL_ID_CONT
    jmp ADMIN_MENU
DEL_ID_CONT:
    mov userID, r24
    call LCD_DATA

    ; ID Validation
    mov r20, userID
    subi r20, '1'
    lsl r20
    lsl r20
    inc r20
    mov r17, r20
    ldi r18, 0
    call EEPROM_READ
    cpi temp, 0xFF
    brne ASK_PASS_DEL

    call LCD_L2
    ldi ZL, low(MSG_NO_USER*2)
    ldi ZH, high(MSG_NO_USER*2)
    call LCD_STR
    call DELAY_2S
    jmp ADMIN_MENU

ASK_PASS_DEL:
    call LCD_L2
    ldi ZL, low(MSG_SYS_REQ*2)
    ldi ZH, high(MSG_SYS_REQ*2)
    call LCD_STR
    call INPUT_PASS
    cpi r24, 0xFF
    brne DEL_PASS_CONT
    jmp ADMIN_MENU

DEL_PASS_CONT:
    ldi ZL, low(CURRENT_PASS)
    ldi ZH, high(CURRENT_PASS)
    ld r20, Z+
    cpi r20, '1'
    brne DEL_FAIL
    ld r20, Z+
    cpi r20, '2'
    brne DEL_FAIL
    ld r20, Z+
    cpi r20, '3'
    brne DEL_FAIL
    ld r20, Z+
    cpi r20, '4'
    brne DEL_FAIL
    rjmp DEL_DO_DELETE

DEL_FAIL:
    jmp LOGIN_FAIL

DEL_DO_DELETE:
    ; Re-calculate the specific user's EEPROM address to delete them
    mov r20, userID
    subi r20, '1'
    lsl r20
    lsl r20
    inc r20
    mov r17, r20
    ldi r18, 0
    ldi temp, 0xFF ; Mark ID slot as empty
    call EEPROM_WRITE

    call LCD_CLEAR
    ldi ZL, low(MSG_DELETED*2)
    ldi ZH, high(MSG_DELETED*2)
    call LCD_STR
    call DELAY_2S
    jmp ADMIN_MENU


; DRIVERS

INPUT_PASS:
    ldi counter, 0
    ldi YL, low(CURRENT_PASS)
    ldi YH, high(CURRENT_PASS)
IP_L:
    call GET_KEY
    cpi r24, '*'
    brne IP_NOT_BACK
    ldi r24, 0xFF
    ret
IP_NOT_BACK:
    cpi r24, '#'
    brne IP_NOT_CLOSE
    ldi r24, 0xFE
    ret
IP_NOT_CLOSE:
    st Y+, r24
    ldi r24, '*'
    call LCD_DATA
    inc counter
    cpi counter, 4
    brne IP_L
    ldi r24, 0
    ret

EEPROM_WRITE:
    sbic EECR, EEPE
    rjmp EEPROM_WRITE
    out EEARH, r18
    out EEARL, r17
    out EEDR, temp
    sbi EECR, EEMPE
    sbi EECR, EEPE
    ret

EEPROM_READ:
    sbic EECR, EEPE
    rjmp EEPROM_READ
    out EEARH, r18
    out EEARL, r17
    sbi EECR, EERE
    in temp, EEDR
    ret

GET_KEY:
    call SCAN
    tst r24
    breq GET_KEY
    push r24
REL: call DELAY_MS
    call SCAN
    tst r24
    brne REL
    pop r24
    ret

SCAN: ;getting keypad input
    ldi r24, 0
    cbi PORTB, 1
    sbis PINB, 4
    ldi r24, '1'
    sbis PINB, 3
    ldi r24, '2'
    sbis PINB, 2
    ldi r24, '3'
    sbi PORTB, 1
    tst r24
    brne KF
    cbi PORTB, 0
    sbis PINB, 4
    ldi r24, '4'
    sbis PINB, 3
    ldi r24, '5'
    sbis PINB, 2
    ldi r24, '6'
    sbi PORTB, 0
    tst r24
    brne KF
    cbi PORTD, 7
    sbis PINB, 4
    ldi r24, '7'
    sbis PINB, 3
    ldi r24, '8'
    sbis PINB, 2
    ldi r24, '9'
    sbi PORTD, 7
    tst r24
    brne KF
    cbi PORTD, 6
    sbis PINB, 4
    ldi r24, '*'
    sbis PINB, 3
    ldi r24, '0'
    sbis PINB, 2
    ldi r24, '#'
    sbi PORTD, 6
KF: ret

;initializing the LCD screen
LCD_INIT:
    call DELAY_100MS
    ldi r24, 0x02
    call LCD_N_CMD
    ldi r24, 0x28
    call LCD_CMD
    ldi r24, 0x0C
    call LCD_CMD
    ldi r24, 0x01
    call LCD_CMD
    ret

LCD_CMD:
    push r24
    swap r24
    call LCD_N_CMD
    pop r24
    call LCD_N_CMD
    call DELAY_MS
    ret

LCD_DATA:
    push r24
    swap r24
    call LCD_N_DATA
    pop r24
    call LCD_N_DATA
    call DELAY_MS
    ret

LCD_N_CMD:
    cbi PORTC, 4
    rjmp LCD_PHYS
LCD_N_DATA:
    sbi PORTC, 4
LCD_PHYS:
    andi r24, 0x0F
    in temp, PORTC
    andi temp, 0xF0
    or temp, r24
    out PORTC, temp
    sbi PORTC, 5
    nop
    cbi PORTC, 5
    ret

LCD_STR:
    lpm r24, Z+
    tst r24
    breq LSX
    call LCD_DATA
    rjmp LCD_STR
LSX: ret

LCD_CLEAR:
    ldi r24, 0x01
    call LCD_CMD
    ret

LCD_L2: ;move the cursor to the second line
    ldi r24, 0xC0
    call LCD_CMD
    ret

; delay functions
DELAY_MS: ;10ms delay
    ldi r25, 60
D1: ldi r26, 150
D2: dec r26
    brne D2
    dec r25
    brne D1
    ret

DELAY_2S: ;2second delay
    ldi r21, 200
D2S:
    call DELAY_MS
    dec r21
    brne D2S
    ret

DELAY_100MS: ;100ms delay
    ldi r21, 10
DX:
    call DELAY_MS
    dec r21
    brne DX
    ret


; Data Strings

.align 2
MSG_MENU1:    .db "1:Log 2:Admin   ", 0
MSG_MENU2:    .db "*:Back #:Close ", 0
MSG_ADM_M1:   .db "1:Reg 2:Del     ", 0
MSG_ADM_M2_EXT:.db "9:Reset *:Back  ", 0
MSG_EMPTY:    .db "No Users Stored", 0
MSG_GET_ID:   .db "User ID: ", 0
MSG_NO_USER:  .db "No such user    ", 0
MSG_ID_ASSIGN:.db "Assigned ID:", 0
MSG_DEL_ID:   .db "Del User ID: ", 0
MSG_SYS_REQ:  .db "Admin pass: ", 0
MSG_ENTER:    .db "Enter pass: ", 0
MSG_OK:       .db "Access Allowed ", 0
MSG_FAIL:     .db "Access Denied  ", 0
MSG_SAVED:    .db "Pass Stored!    ", 0
MSG_DELETED:  .db "Deleted!        ", 0
MSG_RESETTING:.db "Memory Cleared! ", 0