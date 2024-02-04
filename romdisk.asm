; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様�
;  ROM-DISK か� �┴牀-80 (����皰� ��)
; 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様�

	CPU		8080
	Z80SYNTAX	EXCLUSIVE

; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�
; ���牀� ���矗��� �むメ�
; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�

CHK	MACRO	adr, msg
		IF	$<>(adr)
			ERROR	msg
		ENDIF
	ENDM

; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�
; ���� 0-7FF. ��爛Д燿�牀��� ��� ORDOS
; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�

	ORG	0
	DB	0800h-$ DUP (0FFH)
	CHK	0800H, "* Control address is bad ! *"

; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�
; �������� 瓱痰ガ� � 筮爼�皀 ORDOS
; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�

FILE	MACRO name, start, size
	DB	(0fff0h-$) & 0fh dup (0)	; �諤�↓│��┘ �� �����罐 16
s	SET	$
	DB	name
	DB	8-($-s) DUP (20H)
	DW	start
	DW	size
	DB	080H
	DB	0,0,0
	ENDM

ENDOFFILES	MACRO
	DB	(0fff0h-$) & 0fh dup (0)	; �諤�↓│��┘ �� �����罐 16
	DB	0FFH
	ENDM

	FILE "BASIC$", 0, BASICROMEND-BASICROM
BASICROM:
	BINCLUDE "basic80-48kb.bin"
BASICROMEND:

	FILE "BASIC2$", 0, BASIC2ROMEND-BASIC2ROM
BASIC2ROM:
	BINCLUDE "basic80-service-48kb.bin"
BASIC2ROMEND:

	FILE "TETRIS$", 3000h, TETRISROMEND-TETRISROM
TETRISROM:
	BINCLUDE "tetris.bin"
TETRISROMEND:

	ENDOFFILES

	DB	07E00h-$ DUP (0FFH)

; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�
; ��������� ���������� ROM-DISK/32K
; 陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳陳�

	BINCLUDE "romctrl.rom"

	DB	08000h-$ DUP (0FFH)
	CHK	08000H, "* Control address is bad ! *"
	END 				;

