
; ===========================================================================
;
;   >>>>       Радио-86РК совместимый монитор для Микро-80           <<<<
;
;   Исходный код: А.Покладов, А.Соколов, А.Долгий. журнал Радио N11 1989 г.
;
;   Disassembled by: vlad6502.livejournal.com
;
; ===========================================================================

;P_JMP   EQU     0F750H          ; здесь JMP по G
;PAR_HL  EQU     0F751H
;PAR_DE  EQU     0F753H
;PAR_BC  EQU     0F755H
;EK_ADR  EQU     0F75AH
;YF765   EQU     0F765H
;COMBUF  EQU     0F77BH
;STACK   EQU     0F7FFH
                CPU	8080

DefaultRdWrConst	EQU	03854H
ScreenHeight		EQU	20H
ScreenWidth		EQU	40H
SymbolBufEndHI		EQU	0F0H
CursorBufferStart	EQU	0E000H
SymbolBufferStart	EQU	0E800H

		ORG 0F000h
word_F000:	DS 75Ah
CursorAddress:	DS 2
TapeReadConst:	DS 1		
TapeWriteConst:	DS 1		
CursorVisible:	DS 1		; Show / Hide cursor ESC sequence $1B +	$61; $1B + $62
EscSequenceState: DS	1
LastKeyStatus:	DS 2		; H - last key pressed,	L - autorepeat delay counter
RST6_VAR3:	DS 2		
RST6_VAR1:	DS 2		
		DS 4
F7FE_storedHere:DS 2		; $F7FE	is stored here
RST6_VAR2:	DS 2		
		DS 3
RST6_RUN_Var1:	DS 2		
RST6_RUN_Var2:	DS 1	
JMPcommand:	DS 1		
					; $C3  "JMP" command is stored here
JMPaddress:	DS 2		
word_F777:	DS 2
word_F779:	DS 2
byte_F77B:	DS 1		
TapeReadVAR:	DS 1
HookActive:	DS 1		; is not 0 if hook routine is active
HookJmp:	DS 1		
					; Monitor writes here ;C3 = "JMP" instruction
HookAddress:	DS 2		
FreeMemAddr:	DS 2
CmdLineBuffer:	DS 7Ch		

; ===========================================================================

; Segment type:	Pure code
		ORG 0F800h
		jmp	ColdReset

		jmp	InputSymbol

		jmp	TapeReadByte

		jmp	PrintCharFromC

		jmp	TapeWriteByte

		jmp	HookJmp		; Entry	point for direct call of PrintChar Hook	subroutine

		jmp	GetKeyboardStatus

		jmp	PrintHexByte

		jmp	PrintString

		jmp	ReadKeyCode

		jmp	GetCursorPos

		jmp	ReadVideoRAM

		jmp	TapeReadBlock

		jmp	TapeWriteBlock

		jmp	CalcChecksum

		ret			; Init display refresh (dummy)

		DW  0
		jmp	GetFreeMemAddr

		jmp	SetFreeMemAddr


ColdReset:				
		lxi	sp, 0F800h	; init stack pointer

		; Welcome message block	  -----> ! move	after Clear Area block
		lxi	h, WelcomeMsg	; "\x1F\nm/80k "
		call	PrintString

		; Clear	area $F75D..$F7A2
		lxi	h, 0F75Dh
		lxi	d, 0F7A2h
		lxi	b, 0
		call	DirectiveFill

		mvi	a, 0C3h		; CPU instruction "JMP"
		sta	HookJmp
;
;
;  ----> ! Move	HERE Welcome Message block !
;
		; Find RAM end
		lxi	h, 0


ContinueSearch:				
		mov	c, m
		mvi	a, 55h
		mov	m, a
		xra	m
		mov	b, a
		mvi	a, 0AAh
		mov	m, a
		xra	m
		ora	b
		jnz	RamEndFound

		mov	m, c
		inx	h
		mov	a, h
		cpi	0E0h		; Look for RAM up to $E000 - VideoRAM
		jz	RamEndFound

		jmp	ContinueSearch


RK86WarmReset:				
		jmp	WarmReset	; $F86C	- RK/86	WarmReset vector (for compatibility)


RamEndFound:				
		dcx	h
		shld	FreeMemAddr
		call	PrintHexWord	; Print	Upper Free Mem address

		lxi	h, DefaultRdWrConst
		shld	TapeReadConst
		lxi	h, DummyHook
		shld	HookAddress
		lxi	h, 0F7FEh	; ???? Why does	it needed ????
		shld	F7FE_storedHere


WarmReset:				
		mvi	a, 83h
		out	4		; Init	BB55
		sta	CursorVisible	; Set CursorVisible (<>	0)
		mvi	a, 0C3h		; "JMP" command
		sta	JMPcommand


ProcessDirective:			
		lxi	sp, 0F800h
		lxi	h, DirectivePrompt ; "\r\n-->"
		call	PrintString

		call	InputDirective

		lxi	h, RK86WarmReset
		push	h
		lxi	h, CmdLineBuffer
		mov	a, m
		cpi	'X'
		jz	DirectiveRegisters

		push	psw
		call	sub_F952

		lhld	word_F779
		mov	c, l
		mov	b, h
		lhld	word_F777
		xchg
		lhld	JMPaddress
		pop	psw
		cpi	'D'
		jz	DirectiveDump

		cpi	'C'
		jz	DirectiveCompare

		cpi	'F'
		jz	DirectiveFill

		cpi	'S'
		jz	DirectiveSearch

		cpi	'T'
		jz	DirectiveCopy

		cpi	'M'
		jz	DirectiveModify

		cpi	'G'
		jz	DirectiveRun

		cpi	'I'
		jz	DirectiveTapeInp

		cpi	'O'
		jz	DirectiveTapeOut

		cpi	'W'
		jz	DirectiveSearchWrd

		cpi	'A'
		jz	DirectiveHookAdr

		cpi	'H'
		jz	DirectiveTapeConst

		cpi	'R'
		jz	DirectiveReadROM

		jmp	SyntaxError


ProcessBackspace:			
		mvi	a, CmdLineBuffer & 0FFH
		cmp	l
		jz	GotoCmdLineBegin ; already at the command line beginning

		push	h
		lxi	h, BackspaceStr	; "\b \b"
		call	PrintString

		pop	h
		dcx	h
		jmp	InputNextSymbol


InputDirective:				

		lxi	h, CmdLineBuffer


GotoCmdLineBegin:			
		mvi	b, 0


InputNextSymbol:			
		call	InputSymbol

		cpi	7Fh
		jz	ProcessBackspace

		cpi	8
		jz	ProcessBackspace

		cnz	PrintCharfromA

		mov	m, a
		cpi	0Dh
		jz	ProcessReturn

		cpi	'.'
		jz	ProcessDirective

		mvi	b, 0FFh
		mvi	a, 0A2h	; 'ў'
		cmp	l
		jz	SyntaxError

		inx	h
		jmp	InputNextSymbol


ProcessReturn:				
		mov	a, b
; End of function InputDirective

		ral
		lxi	d, CmdLineBuffer
		mvi	b, 0
		ret


PrintString:				
		mov	a, m
		ana	a
		rz			; Exit when 0 -	string treminator
		call	PrintCharfromA

		inx	h
		jmp	PrintString


sub_F952:				
		lxi	h, JMPaddress
		lxi	d, byte_F77B
		mvi	c, 0
		call	DirectiveFill

		lxi	d,  CmdLineBuffer+1
		call	sub_F980

		shld	JMPaddress
		shld	word_F777
		rc
		mvi	a, 0FFh
		sta	byte_F77B
		call	sub_F980

		shld	word_F777
		rc
		call	sub_F980

		shld	word_F779
		rc
		jmp	SyntaxError


sub_F980:				
		lxi	h, 0


loc_F983:				
		ldax	d
		inx	d
		cpi	0Dh
		jz	loc_F9B4

		cpi	','
		rz
		cpi	' '
		jz	loc_F983

		sui	'0'
		jm	SyntaxError

		cpi	0Ah
		jm	loc_F9A8

		cpi	11h
		jm	SyntaxError

		cpi	17h
		jp	SyntaxError

		sui	7


loc_F9A8:				
		mov	c, a
		dad	h
		dad	h
		dad	h
		dad	h
		jc	SyntaxError

		dad	b
		jmp	loc_F983


loc_F9B4:				
		stc
		ret


Compare_HL_DE:				
		mov	a, h
		cmp	d
		rnz
		mov	a, l
		cmp	e
		ret


Iterate_HL_DE_Brk:			
		call	CheckBreakByKbrd


Iterate_HL_to_DE:			
		call	Compare_HL_DE

		jnz	Inc_HL


loc_F9C5:				
		inx	sp
		inx	sp
		ret


Inc_HL:					
		inx	h
		ret


CheckBreakByKbrd:			
		call	ReadKeyCode

		cpi	3		; Key "“‘+‘"
		rnz
		jmp	SyntaxError

NextLineAndTab:				
		push	h
		lxi	h, NextLineAndTabStr ; "\r\n\x18\x18\x18"
		call	PrintString

		pop	h
		ret

PrintBytePtrHL:				
		mov	a, m

PrintLowHexByte:			
		push	b
		call	PrintHexByte

		call	PrintBlank

		pop	b
		ret

DirectiveReadROM:			
		mvi	a, 90h
		out	0A3h		; BB55 - Control word


ReadNextRomByte:			
		mov	a, l
		out	0A1h		; BB55 - Port B
		mov	a, h
		out	0A2h		; BB55 - Port C
		in	0A0h		; BB55 - Port A
		stax	b
		inx	b
		call	Iterate_HL_to_DE

		jmp	ReadNextRomByte

GetFreeMemAddr:				
		lhld	FreeMemAddr
		ret


SetFreeMemAddr:				
		shld	FreeMemAddr
		ret

DirectiveHookAdr:			
		shld	HookAddress
		ret


DirectiveDump:				
		call	LineFeed

		call	PrintHexWord

		push	h
		mov	a, l
		ani	0Fh
		mov	c, a
		rar
		add	c
		add	c
		adi	5
		mov	b, a
		call	sub_FA5A


loc_FA1A:				
		mov	a, m
		call	PrintHexByte

		call	Compare_HL_DE

		inx	h
		jz	loc_FA32

		mov	a, l
		ani	0Fh
		push	psw
		ani	1
		cz	PrintBlank

		pop	psw
		jnz	loc_FA1A


loc_FA32:				
		pop	h
		mov	a, l
		ani	0Fh
		adi	2Eh ; '.'
		mov	b, a
		call	sub_FA5A


loc_FA3C:				
		mov	a, m
		cpi	7Fh ; ''
		jnc	loc_FA47

		cpi	20h ; ' '
		jnc	loc_FA49


loc_FA47:				
		mvi	a, 2Eh ; '.'


loc_FA49:				
		call	PrintCharfromA

		call	Compare_HL_DE

		rz
		inx	h
		mov	a, l
		ani	0Fh
		jnz	loc_FA3C

		jmp	DirectiveDump

sub_FA5A:				
		lda	CursorAddress
		ani	3Fh
		cmp	b
		rnc
		call	PrintBlank

		jmp	sub_FA5A

PrintBlank:				
		mvi	a, ' '
		jmp	PrintCharfromA


DirectiveCompare:			
		ldax	b
		cmp	m
		jz	NoDifference

		call	PrintNextLnHexWord

		call	PrintBytePtrHL

		ldax	b
		call	PrintLowHexByte


NoDifference:				
		inx	b
		call	Iterate_HL_DE_Brk

		jmp	DirectiveCompare

DirectiveFill:				
		mov	m, c
		call	Iterate_HL_to_DE

		jmp	DirectiveFill

DirectiveSearch:			
		mov	a, c
		cmp	m
		cz	PrintNextLnHexWord

		call	Iterate_HL_DE_Brk

		jmp	DirectiveSearch


DirectiveSearchWrd:			
		mov	a, m
		cmp	c
		jnz	loc_FAA0

		inx	h
		mov	a, m
		cmp	b
		dcx	h
		cz	PrintNextLnHexWord


loc_FAA0:				
		call	Iterate_HL_DE_Brk

		jmp	DirectiveSearchWrd


DirectiveCopy:				
		mov	a, m
		stax	b
		inx	b
		call	Iterate_HL_to_DE

		jmp	DirectiveCopy


DirectiveModify:			
		call	PrintNextLnHexWord

		call	PrintBytePtrHL

		push	h
		call	InputDirective

		pop	h
		jnc	loc_FAC4

		push	h
		call	sub_F980

		mov	a, l
		pop	h
		mov	m, a


loc_FAC4:				
		inx	h
		jmp	DirectiveModify


DirectiveRun:				
		call	Compare_HL_DE

		jz	PlainRun

		xchg
		shld	RST6_RUN_Var1
		mov	a, m
		sta	RST6_RUN_Var2
		mvi	m, 0F7h		; CPU command "RST6"
		mvi	a, 0C3h		; CPU command "JMP"
		sta	30h
		lxi	h, RST6_handler
		shld	31h


PlainRun:				
		lxi	sp, 0F766h
		pop	b
		pop	d
		pop	h
		pop	psw
		sphl
		lhld	RST6_VAR1
		jmp	JMPcommand

RST6_handler:				
		shld	RST6_VAR1
		push	psw
		pop	h
		shld	RST6_VAR2
		pop	h
		dcx	h
		shld	RST6_VAR3
		lxi	h, 0
		dad	sp
		lxi	sp, RST6_VAR2
		push	h
		push	d
		push	b
		lxi	sp, 0F800h
		lhld	RST6_VAR3
		xchg
		lhld	RST6_RUN_Var1
		call	Compare_HL_DE

		jnz	DirectiveRegisters

		lda	RST6_RUN_Var2
		mov	m, a


DirectiveRegisters:			
		lxi	h, RegistersListStr ; "\r\nPC-\r\nHL-\r\nBC-\r\nDE-\r\nSP-\r\nAF-\x19\x19\x19\x19\x19\x19"
		call	PrintString

		lxi	h, RST6_VAR3
		mvi	b, 6


loc_FB27:				
		mov	e, m
		inx	h
		mov	d, m
		push	b
		push	h
		xchg
		call	PrintNextLnHexWord

		call	InputDirective

		jnc	loc_FB3F

		call	sub_F980

		pop	d
		push	d
		xchg
		mov	m, d
		dcx	h
		mov	m, e


loc_FB3F:				
		pop	h
		pop	b
		dcr	b
		inx	h
		jnz	loc_FB27

		jmp	RK86WarmReset


GetCursorPos:				
		push	psw
		lhld	CursorAddress
		mov	a, h
		ani	7
		mov	h, a
		mov	a, l
		ani	3Fh
		adi	8
		dad	h
		dad	h
		inr	h
		inr	h
		inr	h
		mov	l, a
		pop	psw
		ret


ReadVideoRAM:				
		push	h
		lhld	CursorAddress
		mov	a, m
		pop	h
		ret


DirectiveTapeConst:			
		call	NextLineAndTab

		lxi	h, 0FF80h
		mvi	b, 7Bh ; '{'
		in	1
		mov	c, a


loc_FB70:				
		in	1
		cmp	c
		jz	loc_FB70


loc_FB76:				
		mov	c, a


loc_FB77:				
		inx	h
		in	1
		cmp	c
		jz	loc_FB77

		dcr	b
		jnz	loc_FB76

		dad	h
		mov	a, h
		dad	h
		add	h
		mov	l, a
		jmp	PrintHexWord


DirectiveTapeInp:			
		lda	byte_F77B
		ora	a
		jz	loc_FB95

		mov	a, e
		sta	TapeReadConst


loc_FB95:				
		call	TapeReadBlock

		call	PrintNextLnHexWord

		xchg
		call	PrintNextLnHexWord

		xchg
		push	b
		call	CalcChecksum

		mov	h, b
		mov	l, c
		call	PrintNextLnHexWord

		pop	d
		call	Compare_HL_DE

		rz
		xchg
		call	PrintNextLnHexWord


SyntaxError:				
		mvi	a, '?'
		call	PrintCharfromA

		jmp	ProcessDirective


TapeReadBlock:				
		mvi	a, 0FFh
		call	sub_FBDA

		push	h
		dad	b
		xchg
		call	sub_FBD8

		pop	h
		dad	b
		xchg
		in	5
		ani	4
		rz
		push	h
		call	sub_FBE5

		mvi	a, 0FFh
		call	sub_FBDA

		pop	h
		ret


sub_FBD8:				
		mvi	a, 8


sub_FBDA:				
		call	TapeReadByte

		mov	b, a
		mvi	a, 8
		call	TapeReadByte

		mov	c, a
		ret


sub_FBE5:				
		mvi	a, 8
		call	TapeReadByte

		mov	m, a
		call	Iterate_HL_to_DE

		jmp	sub_FBE5


CalcChecksum:				
		lxi	b, 0


loc_FBF4:				
		mov	a, m
		add	c
		mov	c, a
		push	psw
		call	Compare_HL_DE

		jz	loc_F9C5

		pop	psw
		mov	a, b
		adc	m
		mov	b, a
		call	Iterate_HL_to_DE

		jmp	loc_FBF4


DirectiveTapeOut:			
		mov	a, c
		ora	a
		jz	loc_FC10

		sta	TapeWriteConst


loc_FC10:				
		push	h
		call	CalcChecksum

		pop	h
		call	PrintNextLnHexWord

		xchg
		call	PrintNextLnHexWord

		xchg
		push	h
		mov	h, b
		mov	l, c
		call	PrintNextLnHexWord

		pop	h


TapeWriteBlock:				
		push	b
		lxi	b, 0


loc_FC28:				
		call	TapeWriteByte

		dcr	b
		xthl
		xthl
		jnz	loc_FC28

		mvi	c, 0E6h	; 'ж'
		call	TapeWriteByte

		call	sub_FC6C

		xchg
		call	sub_FC6C

		xchg
		call	sub_FC62

		lxi	h, 0
		call	sub_FC6C

		mvi	c, 0E6h	; 'ж'
		call	TapeWriteByte

		pop	h
		call	sub_FC6C

		ret


PrintNextLnHexWord:			
		push	b
		call	NextLineAndTab

		call	PrintHexWord

		pop	b
		ret



PrintHexWord:				
		mov	a, h
		call	PrintHexByte

		mov	a, l
		jmp	PrintLowHexByte


sub_FC62:				
		mov	c, m
		call	TapeWriteByte

		call	Iterate_HL_to_DE

		jmp	sub_FC62



sub_FC6C:				
		mov	c, h
		call	TapeWriteByte

		mov	c, l
		jmp	TapeWriteByte


TapeReadByte:				
		push	h
		push	b
		push	d
		mov	d, a


loc_FC78:				
		mvi	c, 0
		in	1
		ani	1
		mov	e, a


loc_FC7F:				
		mov	a, c
		ani	7Fh
		rlc
		mov	c, a
		mvi	h, 0


loc_FC86:				
		dcr	h
		jz	loc_FCD2

		in	1
		ani	1
		cmp	e
		jz	loc_FC86

		ora	c
		mov	c, a
		dcr	d
		lda	TapeReadConst
		jnz	loc_FC9D

		sui	12h


loc_FC9D:				
		mov	b, a


loc_FC9E:				
		dcr	b
		jnz	loc_FC9E

		inr	d
		in	1
		ani	1
		mov	e, a
		mov	a, d
		ora	a
		jp	loc_FCC6

		mov	a, c
		cpi	0E6h ; 'ж'
		jnz	loc_FCBA

		xra	a
		sta	TapeReadVAR
		jmp	loc_FCC4


loc_FCBA:				
		cpi	19h
		jnz	loc_FC7F

		mvi	a, 0FFh
		sta	TapeReadVAR


loc_FCC4:				
		mvi	d, 9


loc_FCC6:				
		dcr	d
		jnz	loc_FC7F

		lda	TapeReadVAR
		xra	c
		pop	d
		pop	b
		pop	h
		ret


loc_FCD2:				
		mov	a, d
		ora	a
		jp	SyntaxError

		call	CheckBreakByKbrd

		jmp	loc_FC78


TapeWriteByte:				
		push	b
		push	d
		push	psw
		mvi	d, 8


loc_FCE2:				
		mov	a, c
		rlc
		mov	c, a
		mvi	a, 1
		xra	c
		out	1
		lda	TapeWriteConst
		mov	b, a


loc_FCEE:				
		dcr	b
		jnz	loc_FCEE

		mvi	a, 0
		xra	c
		out	1
		dcr	d
		lda	TapeWriteConst
		jnz	loc_FD00

		sui	0Eh


loc_FD00:				
		mov	b, a


loc_FD01:				
		dcr	b
		jnz	loc_FD01

		inr	d
		dcr	d
		jnz	loc_FCE2

		pop	psw
		pop	d
		pop	b
		ret


PrintHexByte:				
		push	psw
		rrc
		rrc
		rrc
		rrc
		call	sub_FD17

		pop	psw


sub_FD17:				
		ani	0Fh
		cpi	0Ah
		jm	loc_FD20

		adi	7


loc_FD20:				
		adi	30h ; '0'


PrintCharfromA:				
		mov	c, a


PrintCharFromC:				

		push	psw
		push	b
		push	d
		push	h
		call	GetKeyboardStatus ; ???? how it	works ??? Result is disrupted by following code

		mvi	b, 0		; Hide cursor in current position
		call	ShowHideCursor

		lhld	CursorAddress
		lda	EscSequenceState
		dcr	a
		jm	NotInEscSequence ; if EscCurPosState = 0

		jz	CheckIf59escCode ; if EscCurPosState = 1 - $1B ESC was found before

		dcr	a
		jnz	ProcessEsc59ArgX ; if EscCurPsState = 3	- $1B+$59 was found before


		; Process Esc59	argument Y
		mov	a, c
		sui	20h
		jp	CheckUpBound

		xra	a		; if Y < 0 then	set Y =	0
		jmp	ConvertYtoVideoAddr


CheckUpBound:				
		cpi	ScreenHeight
		jm	ConvertYtoVideoAddr

		mvi	a, ScreenHeight-1


ConvertYtoVideoAddr:			
		rrc
		rrc
		mov	c, a
		ani	0C0h
		mov	b, a
		mov	a, l
		ani	3Fh
		ora	b
		mov	l, a
		mov	a, c
		ani	7
		mov	b, a
		mov	a, h
		ani	0F8h
		ora	b
		mov	h, a
		mvi	a, 3


UpdateEscCurPsState:			
		sta	EscSequenceState


UpdCurPosAndReturn:			
		shld	CursorAddress


ShowCursorAndReturn:			
		mvi	b, 0FFh		; Show cursor in new position
		call	ShowHideCursor

		pop	h
		pop	d
		pop	b
		pop	psw
		ret


ShowHideCursor:				
		lda	CursorVisible
		ora	a
		rz			; exit if a=0(hide) or CursorVisible = 0
		lhld	CursorAddress
		lxi	d, 0F801h	; $F801	= -$7FF
		dad	d		; Calculate Cursor buffer position
		mov	m, b
		ret

ProcessEsc59ArgX:			
		mov	a, c
		sui	20h
		jp	CheckRightBound

		xra	a		; if X < 0 - Set X=0
		jmp	ConvertXToVideoAddr


CheckRightBound:			
		cpi	ScreenWidth
		jm	ConvertXToVideoAddr

		mvi	a, ScreenWidth-1


ConvertXToVideoAddr:			
		mov	b, a
		mov	a, l
		ani	0C0h
		ora	b
		mov	l, a


EndEscSequence:				
		xra	a		; ;  no	ESC sequence in	progress
		jmp	UpdateEscCurPsState


CheckIf59escCode:			
		mov	a, c
		cpi	59h		; $1B +	$59   (ESC codes - set cursor position)
		jnz	CheckIf61escCode

		mvi	a, 2		; 59h ESC code found
		jmp	UpdateEscCurPsState


CheckIf61escCode:			
		cpi	61h
		jnz	CheckIf62escCode

		xra	a		; Hide cursor
		jmp	UpdateEsc6162


CheckIf62escCode:			
		cpi	62h
		jnz	EndEscSequence


UpdateEsc6162:				
		sta	CursorVisible
		jmp	EndEscSequence


NotInEscSequence:			
		in	5
		ani	6		; wait for "“‘"+"CC" keys unpressed
		jz	NotInEscSequence ; <---- !!! Not Clear how it works !!!

		mvi	a, 10h		; 10h ESC code - PrintCHar hook	on / off
		cmp	c
		lda	HookActive
		jnz	GoHookAndPrint

		cma
		sta	HookActive
		jmp	UpdCurPosAndReturn


GoHookAndPrint:				
		ora	a
		cnz	HookJmp		; Call hook subroutine if HookActive <>	0

		mov	a, c
		cpi	1Fh
		jz	DoClearScreen

		jm	ProcessEscCodes


DoPrintChar:				
		mov	m, a
		inx	h
		mov	a, h
		cpi	SymbolBufEndHI
		jm	UpdCurPosAndReturn

		call	LineFeed

		jmp	ShowCursorAndReturn


DoClearScreen:				
		mvi	b, ' '
		mvi	a, 0F0h		; This is Video	RAM end	for Clear Screen = let keep it always $F0
		lxi	h, CursorBufferStart


ClearNextScrPos:			
		mov	m, b
		inx	h
		mov	m, b
		inx	h
		cmp	h
		jnz	ClearNextScrPos


DoCursorHome:				
		lxi	h, SymbolBufferStart
		jmp	UpdCurPosAndReturn


ProcessEscCodes:			
		cpi	0Ch
		jz	DoCursorHome

		cpi	0Dh
		jz	DoReturn

		cpi	0Ah
		jz	DoLineFeed

		cpi	8
		jz	DoCursorLeft

		cpi	18h
		jz	DoCursorRight

		cpi	19h
		jz	DoCursorUp

		cpi	7
		jz	DoBeep

		cpi	1Ah
		jz	DoCursorDown

		cpi	1Bh
		jnz	DoPrintChar

;
;		DoSetCursorPosition
		mvi	a, 1		; 1Bh ESC code found
		jmp	UpdateEscCurPsState


;-----------------------------------------------

DoBeep:					
		mvi	c, 80h
		mvi	e, 20h


WaweRepeat:				
		mov	d, e


DelayLoop1:				
		mvi	a, 0Fh
		out	4
		dcr	e
		jnz	DelayLoop1

		mov	e, d


DelayLoop2:				
		mvi	a, 0Eh
		out	4
		dcr	d
		jnz	DelayLoop2

		dcr	c
		jnz	WaweRepeat

		jmp	ShowCursorAndReturn

;-------------------------------------------

DoReturn:				
		mov	a, l
		ani	0C0h
		mov	l, a
		jmp	UpdCurPosAndReturn


DoCursorRight:				
		inx	h


CheckVertBoundary:			
		mov	a, h
		ani	7
		ori	(SymbolBufferStart & 0FF00H) >> 8
		mov	h, a
		jmp	UpdCurPosAndReturn


DoCursorLeft:				
		dcx	h
		jmp	CheckVertBoundary


DoLineFeed:				
		lxi	b, ScreenWidth
		dad	b
		mov	a, h
		cpi	SymbolBufEndHI	; Upper	Video Memory bound (HI byte)
		jm	UpdCurPosAndReturn


		; Scroll screen	up
		lxi	h, SymbolBufferStart
		lxi	b, SymbolBufferStart+ScreenWidth


ContinueScroll:				
		ldax	b
		mov	m, a
		inx	h
		inx	b
		ldax	b
		mov	m, a
		inx	h
		inx	b
		mov	a, b
		cpi	SymbolBufEndHI
		jm	ContinueScroll

		mvi	a, SymbolBufEndHI
		mvi	c, ' '


ClearLastLine:				
		mov	m, c
		inx	h
		mov	m, c
		inx	h
		cmp	h
		jnz	ClearLastLine

		lhld	CursorAddress
		mvi	h, SymbolBufEndHI-1 ; Position cursor in Last Line
		mov	a, l
		ori	0C0h
		mov	l, a		; Keep X cursor	position
		jmp	UpdCurPosAndReturn


DoCursorUp:				
		lxi	b, -ScreenWidth	; $FFC0	= -64


AddBXtoHL:				
		dad	b
		jmp	CheckVertBoundary


DoCursorDown:				
		lxi	b, ScreenWidth
		jmp	AddBXtoHL

LineFeed:				
		mvi	c, 0Dh
		call	PrintCharFromC

		mvi	c, 0Ah
		jmp	PrintCharFromC


GetKeyboardStatus:			
		xra	a
		out	7
		in	6
		ani	7Fh
		cpi	7Fh
		jnz	KeyIsPressed

		xra	a
		ret


KeyIsPressed:				
		mvi	a, 0FFh
		ret


InputSymbol:				
		push	h
		lhld	LastKeyStatus
		call	WaitKeyStateChange

		mvi	l, 20h		; Autorepeat rate delay
		jz	Autorepeat


loc_FED4:				
		mvi	l, 2
		call	WaitKeyStateChange

		jnz	loc_FED4

		cpi	80h ; 'Ђ'
		jnc	loc_FED4

		mvi	l, 80h		; Autorepeat start delay


Autorepeat:				
		shld	LastKeyStatus
		pop	h
		ret

WaitKeyStateChange:			
		call	ReadKeyCode

		cmp	h
		jnz	KeyStateChanged

		push	psw
		xra	a


DoDelay:				
		xchg
		xchg
		dcr	a
		jnz	DoDelay

		pop	psw
		dcr	l
		jnz	WaitKeyStateChange


KeyStateChanged:			
		mov	h, a
		ret


ReadKeyCode:				
		push	b
		push	d
		push	h
		lxi	b, 0FEh
		mvi	d, 8


loc_FF06:				
		mov	a, c
		out	7
		rlc
		mov	c, a
		in	6
		ani	7Fh
		cpi	7Fh
		jnz	loc_FF28

		mov	a, b
		adi	7
		mov	b, a
		dcr	d
		jnz	loc_FF06

		in	5
		rar
		mvi	a, 0FFh
		jc	ReturnFromReadKey

		dcr	a
		jmp	ReturnFromReadKey


loc_FF28:				
		rar
		jnc	loc_FF30

		inr	b
		jmp	loc_FF28


loc_FF30:				
		mov	a, b
		cpi	30h ; '0'
		jnc	GenerateEscCode

		adi	30h ; '0'
		cpi	3Ch ; '<'
		jc	loc_FF44

		cpi	40h ; '@'
		jnc	loc_FF44

		ani	2Fh


loc_FF44:				
		cpi	5Fh ; '_'
		jnz	loc_FF4B

		mvi	a, 7Fh ; ''


loc_FF4B:				
		mov	c, a
		in	5
		ani	7
		cpi	7
		mov	b, a
		mov	a, c
		jz	ReturnFromReadKey

		mov	a, b
		rar
		rar
		jnc	loc_FF68

		rar
		jnc	loc_FF6E

		mov	a, c
		ori	20h


ReturnFromReadKey:			
		pop	h
		pop	d
		pop	b
		ret


loc_FF68:				
		mov	a, c
		ani	1Fh
		jmp	ReturnFromReadKey


loc_FF6E:				
		mov	a, c
		cpi	7Fh ; ''
		jnz	loc_FF76

		mvi	a, 5Fh ; '_'


loc_FF76:				
		cpi	40h ; '@'
		jnc	ReturnFromReadKey

		cpi	30h ; '0'
		jnc	loc_FF85

		ori	10h
		jmp	ReturnFromReadKey


loc_FF85:				
		ani	2Fh
		jmp	ReturnFromReadKey


GenerateEscCode:			
		lxi	h, ESCcodesMap
		sui	30h ; '0'
		mov	c, a
		mvi	b, 0
		dad	b
		mov	a, m
		jmp	ReturnFromReadKey

; End of function ReadKeyCode

ESCcodesMap:	db  20h		
		db  18h
		db    8
		db  19h
		db  1Ah
		db  0Dh
		db  1Fh
		db  0Ch
DirectivePrompt:db 0Dh, 0Ah		
		db "-->"
		db 0
NextLineAndTabStr:db 0Dh, 0Ah,	18h, 18h, 18h, 0 
RegistersListStr:db 0Dh, 0Ah		
		db "PC-"
		db 0Dh, 0Ah
		db "HL-"
		db 0Dh, 0Ah
		db "BC-"
		db 0Dh, 0Ah
		db "DE-"
		db 0Dh, 0Ah
		db "SP-"
		db 0Dh, 0Ah
		db "AF-"
		db 19h, 19h, 19h, 19h,	19h, 19h, 0
BackspaceStr:	db 8			
		db " "
		db 8, 0
WelcomeMsg:	db 1Fh, 0Ah		
		db "m/80k "
		db 0
DummyHook:	db 0C9h		
					; CPU instruction "RET"  - dummy PrintChar hook
		db 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
		db 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
		db 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
		db 0FFh,0FFh,0FFh,0FFh
; end of 'ROM'


		;.end
