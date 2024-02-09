			CPU	8080
			Z80SYNTAX EXCLUSIVE

			ORG	00000H

STACK			EQU	3600H
RAMTOP			EQU	3600H

;			INCLUDE	"MONITOR.INC"

			PHASE	0h

			JP	INIT			; ����� ����� � coldstart
IOByte:			DB	54H			; I/O byte, ������ ������� �� ��������������
CURDSK:			DB	'A'			; Current command processor drive (low 4 bits) and user number (high 4 bits). ������ ������� �� ��������������
			JP	RAMTOP-100H		; ����� ����� � BDOS

BDOS			LD	HL, 0000H		; ������ BDOS
			ADD	HL, SP
			LD	(OLDSP), HL
			LD	SP, STACK
			DEC	C
			JP	M, 0F800H		; ������� 0
			LD	HL, BDOSRET
			PUSH	HL
			LD	A, C
			LD	C, E
			JP	Z, FUNC01		; ������� 1
			DEC	A
			JP	Z, 0F809H		; ������� 2
			SUB	04H
			JP	Z, FUNC06		; ������� 6
			SUB	03H
			JP	Z, FUNC09		; ������� 9
			JP	SkipSignature

			DB	"GORSHKOFF D"

SkipSignature:		DEC	A
			JP	Z, FUNC0A		; ������� 10
			DEC	A
			JP	Z, 0F812H		; ������� 11
			DEC	A
			JP	NZ, 0F800H		; ������� 13 � ����
			LD	A, 20H			; ������� 12
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

; ���� �������� ����� ����� BIOS
BIOSENTRY:
			JP	BDOS			; CBOOT �������� �����
			JP	0F800H			; WBOOT ������ �����
			JP	0F812H			; CONST ������ �������
			JP	0F803H			; CONIN ���������� ����
			JP	0F809H			; CONOUT ���������� �����
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

BDOSRET:		LD	HL, (OLDSP)		; ����� �������� �� ������� BDOS
			LD	SP, HL
			LD	L, A
			LD	H, B
			RET

DEL:			DB	8, ' ', 8, '$'

			; ��������� �������������.
			; ���������� �������� BIOS � ������� ������ ������
			; ������������ ����� ����� � BIOS
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
						
			;JP	0100H			; ������ ��  ������ ���������

