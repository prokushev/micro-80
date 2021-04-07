			CPU	Z80
			ORG	00000H

STACK			EQU	3600H
RAMTOP			EQU	3600H

;			INCLUDE	"MONITOR.INC"

			PHASE	0h

			JP	INIT			; Точка входа в coldstart
IOByte:			DB	54H			; I/O byte, данной версией не поддерживается
CURDSK:			DB	'A'			; Current command processor drive (low 4 bits) and user number (high 4 bits). Данной версией не поддерживается
			JP	RAMTOP-100H		; Точка входа в BDOS

BDOS			LD	HL, 0000H		; Начало BDOS
			ADD	HL, SP
			LD	(OLDSP), HL
			LD	SP, STACK
			DEC	C
			JP	M, 0F800H		; Функция 0
			LD	HL, BDOSRET
			PUSH	HL
			LD	A, C
			LD	C, E
			JP	Z, FUNC01		; Функция 1
			DEC	A
			JP	Z, 0F809H		; Функция 2
			SUB	04H
			JP	Z, FUNC06		; Функция 6
			SUB	03H
			JP	Z, FUNC09		; Функция 9
			JP	SkipSignature

			DB	"GORSHKOFF D"

SkipSignature:		DEC	A
			JP	Z, FUNC0A		; Функция 10
			DEC	A
			JP	Z, 0F812H		; Функция 11
			DEC	A
			JP	NZ, 0F800H		; Функции 13 и выше
			LD	A, 20H			; Функция 12
			LD	B, 00H
			;LD	H, B
			;LD	L, A
			RET

FUNC06:			INC	E
			JP	NZ,0F809H
			CALL	0F812H
			RET	Z
			JP	0F803H

OLDSP:			DW	0

			NOP
			NOP
			NOP

FCB1:			DB	' ',' '

FUNC09:			EX	DE, HL
FUNC09LP:		LD	C, (HL)
			LD	A, '$'
			CP	C
			RET	Z

			CALL	0F809H
			INC	HL
			JP	FUNC09LP

			db	87h	;        add     a,a

FCB2:			DB	' ',' '

; Блок эмуляции точек входа BIOS
BIOSENTRY:
			JP	BDOS			; CBOOT Холодный старт
			JP	0F800H			; WBOOT Теплый старт
			JP	0F812H			; CONST Статус консоли
			JP	0F803H			; CONIN Консольный ввод
			JP	0F809H			; CONOUT Консольный вывод
BIOSENTRYEND:		EQU	$


			db 	0cdh,0bch,020h    ; call    20bch
			
			nop
			nop
			nop
			nop
			nop
			nop
			


FUNC0A:			LD	L, E
			LD	H, D
			LD	C, (HL)
			LD	B, 00H
			INC	HL
L008CH:			CALL	0F803H
			CP	08H
			JP	Z, L00B6H
			PUSH	BC
			LD	C, A
			CALL	0F809H
			POP	BC
			CP	0DH
			JP	Z, L00B2H
			CP	0AH
			JP	Z, L00B2H
			CP	03H
			JP	Z, 0F800H
			INC	HL
			LD	(HL), A
			INC	B
			LD	A, C
			CP	B
			JP	NZ, L008CH
			LD	B, C

L00B2H:			INC	DE
			EX	DE, HL
			LD	(HL), B
			RET

L00B6H:			LD	A, B
			OR	A
			JP	Z, L008CH
			DEC	B
			DEC	HL
			PUSH	BC
			PUSH	HL
			LD	HL, DEL
			CALL	FUNC09LP
			POP	HL
			POP	BC
			JP	L008CH

FUNC01:			CALL	0F803H
			LD	C, A
			JP	0F809H

BDOSRET:		LD	HL, (OLDSP)		; Точка возврата из функции BDOS
			LD	SP, HL
			LD	L, A
			LD	H, B
			RET

DEL:			DB	8, ' ', 8, '$'

			; Начальная инициализация.
			; Перемещает эмулятор BIOS в верхние адреса памяти
			; Корректирует точку входа в BIOS
INIT:
			LD	HL, RAMTOP-100H
			LD	(0001H), HL
			LD	HL, BIOSENTRY
			LD	DE, RAMTOP-100h
			LD	C, BIOSENTRYEND-BIOSENTRY
LP:
			LD	A, (HL)
			LD	(DE), A
			INC	HL
			INC	DE
			DEC	C
			JP	NZ, LP
			
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
			nop
						
			;JP	0100H			; Уходим на  начало программы



			if 0
Может быть потом...
			RET				; LIST Printer output
			NOP
			NOP
			JP	0F80CH			; PUNCH Paper tape punch output
			JP	0F806H			; READER Paper tape reader input
			RET				; HOME	;21: Move disc head to track 0
			NOP
			NOP
			RET				; SELDSK	;24: Select disc drive
			NOP
			NOP
			RET				; SETTRK	;27: Set track number
			NOP
			NOP
			RET				; SETSEC	;30: Set sector number
			NOP
			NOP
			RET				; SETDMA	;33: Set DMA address
			NOP
			NOP
			RET				; READ	;36: Read a sector
			NOP
			NOP
			RET				; WRITE	;39: Write a sector
			NOP
			NOP
			RET				; LISTST Status of list device
			NOP
			NOP
			RET				; SECTRAN	;45: Sector translation for skewing				
			endif