; ммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммм
;  ROM-DISK ╓╚О ▄╗╙Ю╝-80 (▄╝╜╗Б╝Ю ░┼)
; ммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммммм

	CPU		8080
	Z80SYNTAX	EXCLUSIVE

; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд
; ▄═╙Ю╝А ╙╝╜БЮ╝╚О ═╓Ю╔А═
; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд

CHK	MACRO	adr, msg
		IF	$<>(adr)
			ERROR	msg
		ENDIF
	ENDM

; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд
; │╚╝╙ 0-7FF. ┤═Ю╔╖╔Ю╒╗Ю╝╒═╜ ╞╝╓ ORDOS
; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд

	ORG	0
	DB	0800h-$ DUP (0FFH)
	CHK	0800H, "* Control address is bad ! *"

; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд
; ■═╘╚╝╒═О А╗АБ╔╛═ ╒ Д╝Ю╛═Б╔ ORDOS
; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд

FILE	MACRO name, start, size
	DB	(0fff0h-$) & 0fh dup (0)	; ╒КЮ═╒╜╗╒═╜╗╔ ╞╝ ёЮ═╜╗Ф╔ 16
s	SET	$
	DB	name
	DB	8-($-s) DUP (20H)
	DW	start
	DW	size
	DB	080H
	DB	0,0,0
	ENDM

ENDOFFILES	MACRO
	DB	(0fff0h-$) & 0fh dup (0)	; ╒КЮ═╒╜╗╒═╜╗╔ ╞╝ ёЮ═╜╗Ф╔ 16
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

; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд
; ▐░▌┐░─▄▄─ ⌠▐░─┌▀┘█┬÷ ROM-DISK/32K
; ддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддддд

	BINCLUDE "romctrl.rom"

	DB	08000h-$ DUP (0FFH)
	CHK	08000H, "* Control address is bad ! *"
	END 				;

