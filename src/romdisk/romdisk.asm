; ═══════════════════════════════════════════════════════════════════════
;  ROM-DISK для Микро-80 (Монитор РК)
; ═══════════════════════════════════════════════════════════════════════

	CPU		8080
	Z80SYNTAX	EXCLUSIVE

; ───────────────────────────────────────────────────────────────────────
; Макрос контроля адреса
; ───────────────────────────────────────────────────────────────────────

CHK	MACRO	adr, msg
		IF	$<>(adr)
			ERROR	msg
		ENDIF
	ENDM

; ───────────────────────────────────────────────────────────────────────
; Блок 0-7FF. Зарезервирован под ORDOS
; ───────────────────────────────────────────────────────────────────────

	ORG	0
	DB	0800h-$ DUP (0FFH)
	CHK	0800H, "* Control address is bad ! *"

; ───────────────────────────────────────────────────────────────────────
; Файловая система в формате ORDOS
; ───────────────────────────────────────────────────────────────────────

FILE	MACRO name, start, size
	DB	(0fff0h-$) & 0fh dup (0)	; выравнивание по границе 16
s	SET	$
	DB	name
	DB	8-($-s) DUP (20H)
	DW	start
	DW	size
	DB	080H
	DB	0,0,0
	ENDM

ENDOFFILES	MACRO
	DB	(0fff0h-$) & 0fh dup (0)	; выравнивание по границе 16
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

	FILE "CPM$", 3100H, CPMROMEND-CPMROM
CPMROM:
	BINCLUDE "loader.bin"
CPMROMEND:

	ENDOFFILES

	DB	07E00h-$ DUP (0FFH)

; ───────────────────────────────────────────────────────────────────────
; ПРОГРАММА УПРАВЛЕНИЯ ROM-DISK/32K
; ───────────────────────────────────────────────────────────────────────

	BINCLUDE "romctrl.rom"

	DB	08000h-$ DUP (0FFH)
	CHK	08000H, "* Control address is bad ! *"
	END 				;

