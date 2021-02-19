; МИКРО-80 CP/M 2.2 CH.COM
; Является обратным портом ЮТ-88 CP/M 2.2 BIOS на МИКРО-80
;
; todo Отвязать от МОНИТОРа (замена вызовов МОНИТОРа tape in/tape out на функции punch/reader BDOS)
; todo Оптимизация по размеру

        ORG     0100h

        ; Entry Point
        ; --- START PROC L0100 ---
L0100:  JP      L01EB

L0103:  DB      "CHANGER VERS 1.1"
        DB      0Dh
        DB      0Ah
        DB      0Dh
        DB      0Ah
        DB      "$READY TR FOR INPUT, PRESS CR.$READY TR FOR OUTPUT, PRESS CR.$READY TR FOR VERIFY, PRESS CR.$READ ERROR."
        DB      0Dh
        DB      0Ah
        DB      "$VERIFY ERROR."
        DB      0Dh
        DB      0Ah
        DB      "$NO SOURCE FILE PRESENT."
        DB      0Dh
        DB      0Ah
        DB      "$NOT ENOUGH MEMORY."
        DB      0Dh
        DB      0Ah
        DB      "$NO DIRECTORY SPACE."
        DB      0Dh
        DB      0Ah
        DB      "$DISK FULL."
        DB      0Dh
        DB      0Ah
        DB      24h             ; '$'
L01E4:  DB      2Eh             ; '.'
        DB      00h
L01E6:  DB      0E9h
        DB      00h
L01E8:  DB      00h
        DB      00h
        DB      00h

L01EB:  LD      SP,0500h
        LD      DE,0103h
        LD      C,09h
        CALL    0005h
        LD      A,(005Dh)
        CP      20h             ; ' '
        JP      NZ,L0209
        LD      DE,0192h
        LD      C,09h
        CALL    0005h
        JP      0000h

L0209:  LD      DE,005Ch
        LD      C,0Fh
        CALL    0005h
        CP      0FFh
        JP      Z,L032D
        LD      HL,0500h
        LD      (L01E4),HL
L021C:  LD      HL,(L01E4)
        EX      DE,HL
        LD      C,1Ah
        CALL    0005h
        LD      DE,005Ch
        LD      C,14h
        CALL    0005h
        OR      A
        JP      NZ,L024E
        LD      HL,(L01E4)
        LD      DE,0080h
        ADD     HL,DE
        LD      (L01E4),HL
        LD      A,H
        LD      HL,(0006h)
        CP      H
        JP      C,L021C
        LD      DE,01ACh
        LD      C,09h
        CALL    0005h
        JP      0000h

L024E:  LD      DE,0136h
        LD      C,09h
        CALL    0005h
        LD      C,01h
        CALL    0005h
        CALL    L031F
        LD      DE,0500h
        LD      HL,(L01E4)
        CALL    L0307
        LD      (L01E6),HL
        LD      HL,(L01E4)
        LD      DE,0500h
        LD      A,L
        SUB     E
        LD      L,A
        LD      A,H
        SBC     A,D
        LD      H,A
        LD      (L01E8),HL
        LD      L,00h
L027B:  LD      C,00h
        CALL    L03F8
        DEC     L
        JP      NZ,L027B
        LD      C,0E6h
        CALL    L03F8
        LD      HL,(L01E6)
        LD      C,L
        CALL    L03F8
        LD      C,H
        CALL    L03F8
        LD      HL,(L01E8)
        LD      C,L
        CALL    L03F8
        LD      C,H
        CALL    L03F8
        EX      DE,HL
        LD      HL,0500h
L02A3:  LD      C,(HL)
        CALL    L03F8
        INC     HL
        DEC     DE
        LD      A,D
        OR      E
        JP      NZ,L02A3
        LD      DE,0155h
        LD      C,09h
        CALL    0005h
        LD      C,01h
        CALL    0005h
        CALL    L031F
        LD      HL,(L01E6)
        LD      A,0FFh
        CALL    L03F4
        CP      L
        JP      NZ,L02F7
        CALL    L0302
        CP      H
        JP      NZ,L02F7
        LD      HL,(L01E8)
        CALL    L0302
        CP      L
        JP      NZ,L02F7
        CALL    L0302
        CP      H
        JP      NZ,L02F7
        EX      DE,HL
        LD      HL,0500h
L02E6:  CALL    L0302
        CP      (HL)
        JP      NZ,L02F7
        INC     HL
        DEC     DE
        LD      A,D
        OR      E
        JP      NZ,L02E6
        JP      0000h

L02F7:  LD      DE,0182h
        LD      C,09h
        CALL    0005h
        JP      0000h

        ; --- START PROC L0302 ---
L0302:  LD      A,08h
        JP      L03F4

        ; --- START PROC L0307 ---
L0307:  LD      BC,0000h
L030A:  LD      A,(DE)
        ADD     A,C
        LD      C,A
        LD      A,00h
        ADC     A,B
        LD      B,A
        INC     DE
        LD      A,D
        CP      H
        JP      NZ,L030A
        LD      A,E
        CP      L
        JP      NZ,L030A
        LD      L,C
        LD      H,B
        RET

        ; --- START PROC L031F ---
L031F:  LD      C,02h
        LD      E,0Dh
        CALL    0005h
        LD      C,02h
        LD      E,0Ah
        JP      0005h

        ; --- START PROC L032D ---
L032D:  LD      DE,0118h
        LD      C,09h
        CALL    0005h
        LD      C,01h
        CALL    0005h
        CALL    L031F
        LD      A,0FFh
        CALL    L03F4
        LD      L,A
        CALL    L0302
        LD      H,A
        LD      (L01E6),HL
        CALL    L0302
        LD      L,A
        CALL    L0302
        LD      H,A
        LD      (L01E8),HL
        EX      DE,HL
        LD      HL,0500h
L0359:  CALL    L0302
        LD      (HL),A
        INC     HL
        DEC     DE
        LD      A,D
        OR      E
        JP      NZ,L0359
        LD      HL,(L01E8)
        LD      DE,0500h
        ADD     HL,DE
        CALL    L0307
        EX      DE,HL
        LD      HL,(L01E6)
        LD      A,D
        CP      H
        JP      NZ,L037C
        LD      A,E
        CP      L
        JP      Z,L0387
L037C:  LD      DE,0174h
        LD      C,09h
        CALL    0005h
        JP      0000h

L0387:  LD      DE,005Ch
        LD      C,16h
        CALL    0005h
        CP      0FFh
        JP      NZ,L039F
        LD      DE,01C1h
        LD      C,09h
        CALL    0005h
        JP      0000h

L039F:  LD      HL,0500h
        LD      (L01E4),HL
L03A5:  LD      HL,(L01E4)
        EX      DE,HL
        LD      C,1Ah
        CALL    0005h
        LD      DE,005Ch
        LD      C,15h
        CALL    0005h
        OR      A
        JP      Z,L03CD
        LD      DE,01D7h
        LD      C,09h
        CALL    0005h
        LD      DE,005Ch
        LD      C,13h
        CALL    0005h
        JP      0000h

L03CD:  LD      HL,(L01E4)
        LD      DE,0080h
        ADD     HL,DE
        LD      (L01E4),HL
        LD      HL,(L01E8)
        LD      A,L
        SUB     80h
        LD      L,A
        LD      A,H
        SBC     A,00h
        LD      H,A
        LD      (L01E8),HL
        OR      L
        JP      NZ,L03A5
        LD      DE,005Ch
        LD      C,10h
        CALL    0005h
        JP      0000h

        ; --- START PROC L03F4 ---
L03F4:  CALL    0F806h
        RET

        ; --- START PROC L03F8 ---
L03F8:  CALL    0F80Ch
        RET

L03FC:  DB      00h
        DB      00h
        DB      00h
        DB      00h
        DB      00h
        DB      00h
        DB      0E6h
        DB      0E1h
        DB      0B1h
