; Disassembly of the file "C:\yuri\m80\Basic80.bin"
; 
; on Saturday, 24 of October 2020 at 03:54 PM
; Это дизассемблер бейсика "МИКРО-80". Имена меток взяты с дизассемблера Altair BASIC 3.2 (4K)
; По ходу разбора встречаются мысли и хотелки
;
; Общие хотелки:
; !!Добавить поддержку каналов и потоков, как в Sinclair Basic, не забывая совместимость с ECMA стандартом
; !!Добавить поддержку дисковых операций через CP/M (с учетом, что под Микро-80 она существует) (ЗЫ: Базироваться на CP/M Бейсике не хочу)
; !!Отвязаться от RST и пересобрать с адреса 100h. Вначале добавить CP/M адаптер. При наличии поддержки дисковых фунок - адаптер не цепляем.
; !!Добавить OPTION BASE для управления индеском массива
;
; БЕЙСИК для МИКРО-80 - Общее устройство
;
; Как распределяется память
;
; !!Вставить описание из журнала
;
;
;
; Lets consider the blocks of memory that follow Basic's own code in turn :
;
; The minimum amount of stack space is 18 bytes - at initialisation, after the user has stated the options they want, the amount of space is reported as "X BYTES FREE", where X is 4096 minus (amount needed for Basic, plus 18 bytes for the stack). With all optional inline functions selected - SIN, RND, and SQR - X works out to 727 bytes. With no optional inline functions selected, the amount increases to 973 bytes.
;
; Код программы
;
; For efficiency, each line of the program would be 'tokenised' before being stored in program space. This tokenisation involved the simple replacement of keywords with keyword IDs. These keyword IDs occupied a single byte, and were easily distinguished from other bytes of the program since they had their top bit set - ie they were in the range of 0x80 to 0xFF.
;
; Consider this line of input :
;
; FOR I=1 TO 10
;
; This would be tokenised to :
;
; 81 " I=1" 95 " 10"
;
; Which is 0x81 (keyword ID for 'FOR') followed by the string " I=1", followed by 0x95 (keyword ID for 'TO') followed by the string " 10". This is 9 bytes, compared to 13 bytes for the untokenised input.
;
; This particular example line of input is meaningless unless it is part of a larger program. As you should know already, each line of a program is prefixed with a line number. These line numbers get stored as 16-bit integers preceding the tokenised line content. Additionally, each line is stored with a pointer to the following line. Let's consider the example input again, this time as a part of a larger program :
;
; 10 FOR I=1 TO 10
; 20 PRINT "HELLO WORLD"
; 30 NEXT I
;
; Assuming that the beginning of program memory was at 0D18, this program would be stored in memory like this:
;
;
;
; So as you can see, each program line has three components :
;
; Pointer to the next line
; Line number
; Tokenised line content
; The final line of the program - the last one in the above diagram - is always present and is always a null pointer to the non-existent next line. This null line, just two bytes long, is there to mark the end of the program.
; 
; 
;
; Variables
; The variable support in this version of Basic is rather limited. There only permitted type of variables is numeric - no strings, structs, and of course no distinction between integers and floating-point numbers. All variables are stored and treated as floating-point.
;
; The second restriction is that variable names were a maximum of two characters in length : the first (mandatory) character had to be alphabetic, and the second (optional) character had to be a digit. Thus the following declarations are invalid :
;
; LET FOO=1	cross
; LET A="HELLO"	cross
; LET AB=A	cross
; Whereas these declarations are valid :
;
; LET A=1	tick
; LET B=2.5	tick
; LET B2=5.6	tick
; 	 
; The fixed-length of variable names greatly simplified their storage. Each variable occupies 6 bytes : two bytes for the name, and four bytes for the floating-point value (fixme: link to fp).
;
; Arrays
;
; Arrays are stored seperately in their own block which immediately follows normal variables and is pointed to by VAR_ARRAY_BASE. An array is declared with the DIM keyword, and this version of Basic has the curious property where declaring an array of n elements results in n+1 elements being allocated, addressable with subscript values from 0 to n inclusive. Thus the following is quite legal :
;
; DIM A(2)
; A(0) = 1
; A(1) = 2
; A(2) = 3
;
; but :
;
; A(3) = 4
;
; results in a Bad Subscript (BS) error.
;
; An array is stored similarly to normal variables in that we lead with the two-byte variable name. This is followed by a 16-bit integer denoting the size in bytes of the array elements; and finally the array elements themselves (4 bytes each). The example array A(2) shown above, if stored at address 0D20, would appear like this :
;
; Address	Bytes	Value	Description
; 0D20	0x4100	'A\0'	Variable name
; 0D22	0x000C	 	Total size, in bytes, of the array elements.
; 0D24	0x81000000	1	Element 0 value
; 0D28	0x82000000	2	Element 1 value
; 0D2C	0x82400000	3	Element 2 value
; 
;
; Program Flow
;
; When a program is RUN, execution begins on the first line of the program. When a line has finished, execution passes to the next line and so on, until the end of the program or a END or STOP instruction is reached.
;
; This is too simple for all but the simplest programs - there are two mechanisms in Basic for altering program flow so that code can run in loops and subroutines be called. These mechanisms are FOR/NEXT for looping, and GOSUB/RETURN for subroutines.
;
; In both FOR and GOSUB cases, the stack is used to store specific information about the program line to return to.
;
	CPU	8080
	Z80SYNTAX	EXCLUSIVE
; 
;********************
;* 1. Интерпретатор *
;********************

;================
;= 1.1 Рестарты =
;================

; Полезной возможностью 8080 является возможность вызова ряда адресов в нижних адресах
; памяти однобайтовой инструкцией вместо стандартных 3-х байтовых вызовов
; CALL и подобными командами. Данные адреса называют адресами "Рестартов"
; and memory-conscious programmers would always put their most-commonly 
; called functions here, thus saving two bytes on every call elsewhere in the program.
; There are 7 restart addresses, spaced at 8 byte intervals from 0000 to 0030 inclusive.
; (NB: There is support for an eighth restart function, RST 7, but Basic makes no use of it).

; Start (RST 0)

; Once the loader had finished loading Basic into memory from paper tape it would jump to 
; address 0000, the very start of the program. Not much needs to be done here - just 
; disable interrupts and jump up to the Init section in upper memory. Notice that the
; jump address here is coloured red, indicating the code is modified by code elsewhere.
; In this case, the jump address is changed to point to Ready once Init has run successfully. (fixme: not yet it isnt).

; Конфигурация
MaxMem	EQU	03FFFH

Start:
	LD	SP, MaxMem
	JP	Init

; Данные байты не используются?
	INC	HL
	EX	(SP),HL

; SyntaxCheck (RST 1)
; Here is a truly beautiful piece of code, it's Golden Weasel richly deserved. It's used at run-time to check syntax in a very cool way : the byte 
; immediately following an RST 1 instruction is not the following instruction, but the keyword or operator ID that's expected to appear in the program 
; at that point. If the keyword or operator is not present, then it Syntax Errors out, but if it is present then the return address is fixed-up - ie 
; advanced one byte - and the function falls into NextChar so the caller has even less work to do. I honestly doubt syntax checks could be done more 
; efficiently than this. Sheer bloody genius.

RST1:
SyntaxCheck:
	LD	A,(HL)
	EX	(SP),HL
	CP	(HL)
	INC	HL
	EX	(SP),HL
	JP	NZ,SyntaxError

;NextChar (RST 2)
;Return next character of input from the buffer at HL, skipping over space characters. The Carry flag is set if the returned character is not alphanumeric, also the zero flag is set if a null character has been reached.

NextChar:
RST2:
	INC	HL
	LD	A,(HL)
	CP	3AH
	RET	NC
	JP	NextChar_tail

;OutChar (RST 3)
;Prints a character to the terminal.

OutChar:
RST3:
	PUSH	AF
	LD	A,(l0217H)
	OR	A
	JP	OutChar_tail

;CompareHLDE (RST 4)
;Compares HL and DE with same logical results (C and Z flags) as for standard eight-bit compares.

CompareHLDE:
RST4:
	LD	A,H
	SUB	D
	RET	NZ
	LD	A,L
	SUB	E
	RET
;
;TERMINAL_X and TERMINAL_Y
;Variables controlling the current X and Y positions of terminal outpu

TERMINAL_Y:	DB		01
TERMINAL_X:	DB		00
;
;FTestSign (RST 5)
;Tests the state of FACCUM. This part returns with A=0 and zero set if FACCUM==0, the tail of the function sets the sign flag and A accordingly (0xFF is negative, 0x01 if positive) before returning.

FTestSign:
RST5:
	LD	A,(FACCUM+3)
	OR	A
	JP	NZ,FTestSign_tail
	RET  
;
;PushNextWord (RST 6)
;Effectively PUSH (HL). First we write the return address to the JMP instruction at the end of the function; then we read the word at (HL) into BC and push it onto the stack; lastly jumping to the return address.
;
PushNextWord:
RST6:
	EX	(SP),HL
	LD	(RST6RET+1),HL
	POP	HL
	JP	RST6_CONT		; Отличие от Altair - место для обработчика RST 7
;
;
;
RST7:
	RET
	NOP
	NOP

RST6_CONT:
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
	INC	HL
	PUSH    BC
RST6RET:
	JP	L04F9		; Это самомодифицирующийся код


; токены и прочие данные
;1.2 Keywords
;There are three groups of keywords :
;
;General keywords. These typically start a statement; examples are LET, PRINT, GOTO and so on.
;Supplementary keywords. Used in statements but not as part of an expression, eg TO, STEP, TAB
;Inline keywords. Only used in expressions, eg, SIN, RND, INT.
; 
;
;KW_INLINE_FNS
;A table of function pointers for the inline keywords.
;

KW_INLINE_FNS:
	DW	Sgn	;12D4
	DW	Int	;1392
	DW	Abs	;12E8
	DW	Usr	;1736
	DW	Fre	;0C7A
	DW	Inp	;0F75
	DW	Pos	;0CA8
	DW	Sqr	;1554
	DW	Rnd	;162A
	DW	Log	;117E
	DW	Exp	;1599
	DW	Cos	;1660
	DW	Sin	;1666
	DW	Tan	;16C3
	DW	Atn	;16D8
	DW	Peek	;1724
	DW	Len	;0EE7
	DW	Str	;0D1F
	DW	Val	;0FC8
	DW	Asc	;0EF6
	DW	Chr	;0F04
	DW	Left	;0F14
	DW	Right	;0F44
	DW	Mid	;0F4E

;KW_ARITH_OP_FNS
;A table of function pointers for the arithmetic operator functions. 
;Four entries of three bytes each; the first entry byte is for operator 
;precedence and the second and third bytes are function pointers.

KW_ARITH_OP_FNS:
	DB	079h
	DW	FAdd	;+ 144C
	DB	079h
	DW	FSub	;- 107D
	DB	07Bh
	DW	FMul	;* 11BA
	DB	07Bh
	DW	FDiv	;/ 1218
	DB	07Fh
	DW	FPower	; ^ 155D
	DB	50H
	DW	FAnd	; AND 0A77
	DB	46H
	DW	FOr	; OR 0A76

 
;KEYWORDS
;String constants for all keywords, including arithmetic operators. Note that the last character of each keyword has bit 7 set to denote that it is the last character; also that the whole table is terminated with a single null byte.

;General keywords

	ORG	088h
; LET и END выкинули зачем-то...

KEYWORDS:
	DB	"CL", 'S'+80h	;	80
	DB	"FO", 'R'+80h	;	81
	DB	"NEX", 'T'+80h	;	82
	DB	"DAT", 'A'+80h	;	83
	DB 	"INPU", 'T'+80h	;	84
	DB 	"DI", 'M'+80h	;	85
	DB 	"REA", 'D'+80h	;	86
	DB 	"CU",	'R'+80h	;	87
	DB 	"GOT", 'O'+80h	;	88
	DB 	"RU", 'N'+80h	;	89
	DB 	"I", 'F'+80h	;	8A
	DB 	"RESTOR", 'E'+80h	;	8B
	DB 	"GOSU", 'B'+80h	;	8C
	DB 	"RETUR", 'N'+80h;	8D
	DB 	"RE", 'M'+80h	;	8E
	DB 	"STO", 'P'+80h	;	8F
	DB	"OU", 'T'+80h	;	90
	DB	"O", 'N'+80h	;	91
	DB	"PLO", 'T'+80h	;	92
	DB	"LIN", 'E'+80h	;	93
	DB	"POK", 'E'+80h	;	94
	DB 	"PRIN", 'T'+80h	;	95
	DB	"DE", 'F'+80h	;	96
	DB	"CON", 'T'+80h	;	97
	DB 	"LIS", 'T'+80h	;	98
	DB 	"CLEA", 'R'+80h	;	99
	DB	"MLOA", 'D'+80h	;	9a
	DB	"MSAV", 'E'+80h	;	9b
	DB 	"NE" , 'W'+80h	;	9c
;Supplementary keywords
	DB 	"TAB", '('+80h	;	9d
	DB 	"T", 'O'+80h	;	9e
	DB	"SPC", '('+80h	;	9f
	DB	"F", 'N'+80h	;	a0
	DB 	"THE", 'N'+80h	;	a1
	DB	"NO", 'T'+80h	;	a2
	DB 	"STE", 'P'+80h	;	a3
;Arithmetic and logical operators
	DB 	"+"+80h		;	a4
	DB 	"-"+80h		;	a5
	DB	"*"+80h		;	a6
	DB 	"/"+80h		;	a7
	DB	'^'+80h		;	a8
	DB	"AN", 'D'+80h	;	a9
	DB	"O", 'R'+80h	;	aa
	DB 	">"+80h		;	ab
	DB	"="+80h		;	ac
	DB 	"<"+80h		;	ad
;Inline keywords
	DB 	"SG", 'N'+80h	;	ae
	DB 	"IN", 'T'+80h	;	af
	DB 	"AB", 'S'+80h	;	b0
	DB 	"US", 'R'+80h	;	b1
	DB	"FR", 'E'+80h	;	b2
	DB	"IN", 'P'+80h	;	b3
	DB	"PO", 'S'+80h	;	b4
	DB 	"SQ", 'R'+80h	;	b5
	DB 	"RN", 'D'+80h	;	b6
	DB	"LO", 'G'+80h	;	b7
	DB	"EX", 'P'+80h	;	b8
	DB	"CO", 'S'+80h	;	b9
	DB 	"SI", 'N'+80h	;	ba
	DB	"TA", 'N'+80h	;	bb
	DB	"AT", 'N'+80h	;	bc
	DB	"PEE", 'K'+80h	;	bd
	DB	"LE", 'N'+80h	;	be
	DB	"STR", '$'+80h	;	bf
	DB	"VA", 'L'+80h	;	c0
	DB	"AS", 'C'+80h	;	c1
	DB	"CHR", '$'+80h	;	c2
	DB	"LEFT", '$'+80h	;	c3
	DB	"RIGHT", '$'+80h	;c4
	DB	"MID", '$'+80h	;	c5
; --------------- Это потом из микрона возмем
;c7:SCREEN$( 1eee 1fd8 1a39
;c8: INKEY$ 1ef6 1fda 1685
;c9: AT 1efc 1fdc 009b
;ca: & 1efe 1fde 16a9
;cb: BEEP 1eff 1fe0 0279
;cc: PAUSE 1f03 1fe2 7913
;cd: VERIFY 1f08 1fe4 0f11
;ce: HOME 1f0e 1fe6 4e7b
;cf: EDIT 1f12 1fe8 7b10
;d0: DELETE 1f16 1fea 10b0
;d1: MERGE 1f1c 1fec 137f
;d2: AUTO 1f21 1fee 5014
;d3: HIMEM 1f25 1ff0 09a6
;d4: @ 1f2a 1ff2 a546
;d5: ASN 1f2b 1ff4 4d09
;d6: ADDR 1f2e 1ff6 2849
;d7: PI 1f32 1ff8 2943
;d8: RENUM 1f34 1ffa 4f52
;d9: ACS 1f39 1ffc 2f4e
;da: LG 1f3c 1ffe 3838
;db: LPRINT 1f3e 2000 6e65
;dc: LLIST 1f44 2002 6075
;Null terminator.
	DB	00	 	 	
 
;
;KW_GENERAL_FNS
;Pointers to the functions for the 20 general keywords at the start of the KEYWORDS table above.



	ORG	0170H
	
KW_GENERAL_FNS:
	DW	Cls		;	END		17B3
	DW	For		;	FOR             0535
	DW	Next		;	NEXT            091D
	DW	Data		;	DATA            06F9
	DW	Input		;	INPUT           0852
	DW	Dim		;	DIM             0B15
	DW	Read		;	READ            0879
	DW	Cur		;	LET             176A
	DW	Goto		;	GOTO            06C7
	DW	Run		;	RUN             06AB
	DW	If		;	IF              0778
	DW	Restore		;	RESTORE         05DB
	DW	Gosub		;	GOSUB           06B7
	DW	Return		;	RETURN          06E3
	DW	Rem		;	REM             06FB
	DW	Stop		;	STOP            05EF
	DW	Out		;	PRINT           0F80
	DW	On		;	LIST            075C
	DW	Plot		;	CLEAR           17C7
	DW	Line		;	NEW             1847
	DW	Poke		;			172C
	DW	Print		;			0791
	DW	Def		;			0CB0
	DW	Cont		;			0617
	DW	List		;			04EE
	DW	Clear		;			0682
	DW	Mload		;			1905
	DW	Msave		;			18EE
	DW	New		;			039D
; ???
	DB 30h, 0B1h
	DB 30h, 0B2h
	DB 30h, 0B3h
	DB 30h, 0B4h
	DB 30h, 0B5h
	DB 30h, 0B6h
	DB 30h, 0B7h
	DB 30h, 0B8h
	DB 30h, 0B9h
	DB 31h, 0B0h
	DB 31h, 0B1h
	DB 31h, 0B2h
	DB 31h, 0B3h
	DB 31h, 0B4h
	DB 31h, 0B5h
	DB 31h, 0B6h
	DB 31h, 0B7h
	DB 31h, 0B8h

             
	org 01ceh

;LINE_BUFFER
;Buffer for a line of input or program, 73 bytes long.
;
;The line buffer is prefixed with this comma. It's here because the INPUT handler defers to the READ handler, which expects items of data (which the line buffer is treated as) to be prefixed with commas. Quite a neat trick!

	DB	','
LINE_BUFFER: 
        DB	9ch
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
	NOP
	DB	32h, 32h, 37h, 30h
	NOP

	ORG     0216h
	NOP     
l0217H:	DB		00		; Контроль вывода символа на экран или Тип последнего введенного с клавиатуры символа 00 - обычный символ FF - управляющий
            
        NOP     
        LD      BC,0FF00H
        CCF     
        RRA     
        LD      (BC),A
        LD      B,00H
        LD      L,E
        LD      (BC),A
        LD      BC,8900H
        RLA     
        NOP     
        NOP     
        NOP     
        NOP     
        LD      B,00H
        LD      L,E
        LD      (BC),A
        RST     38H
        CCF     
        PUSH    DE
        LD      BC,0000H
        NOP     
        NOP     
        LD      (0D517H),HL
        DB		01H
		
CURRENT_LINE:	DW		0FFFFH		; Номер текущей исполняемой строки FFFF - никакая не исполняется
	DB	6eh, 0ah
	db	0,0
	db	0cdh, 3fh

	ORG	0243H
PROGRAM_BASE:
	DW	2201h
VAR_BASE:
	DW	2203h
VAR_ARRAY_BASE:
	DW	2203h
VAR_TOP
	DW	2203h
DATA_PROG_PTR
	DW	2200h
FACCUM:	DB	1fh,02h,84h,87h	; Видимо, мусор. Заменить на DD	0 ?
	db 	0c2h, 20h
	db	32h, 35h,36h, 0 ; "256"
	db	30h, 30h,30h, 0	; "000"
	ORG	025bh
	NOP     
        NOP     
        NOP     
        NOP     
szError:	DB		6fh, 7Bh, 69h, 62h, 6Bh, 0E1h, 00h		; "ОШИБКА"
szIn:		DB		20h, 20h, 77h, 0A0h, 00h 			; "  В "
szOK:		DB		0Dh, 0Ah, 0BDh, 3Eh, 0Dh, 0Ah, 00h		; "=>"
szStop:		DB		0Dh, 0Ah, 73h, 74h, 6Fh, 70h, 0A0h, 00h		; "СТОП "
		
; конец токенов

;=========================
;= 1.4 Utility Functions =
;=========================

;Some useful functions.
;GetFlowPtr
;Sets HL to point to the appropriate flow struct on the stack. On entry, if this was called by the NEXT keyword handler then DE is pointing to the variable following the NEXT keyword.

	ORG 027ah

		
L027A:  LD      HL,0004H
        ADD     HL,SP
L027E:  LD      A,(HL)
        INC     HL
        CP      81H
        RET     NZ

        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        PUSH    HL
L0288:  LD      L,C
L0289:  LD      H,B
        LD      A,D
        OR      E
        EX      DE,HL
        JP      Z,L0292
        EX      DE,HL
        RST     20H
L0292:  LD      BC,000DH
        POP     HL
        RET     Z

        ADD     HL,BC
        JP      L027E
		
;		
;CopyMemoryUp
;Copies a block of memory from BC to HL. Copying is done backwards, down to and including the point where BC==DE. It goes backwards because this function is used to move blocks of memory forward by as little as a couple of bytes. If it copied forwards then the block of memory would overwrite itself.

		
L029B:  CALL    L02BB
L029E:  PUSH    BC
        EX      (SP),HL
        POP     BC
L02A1:  RST     20H
        LD      A,(HL)
        LD      (BC),A
        RET     Z

        DEC     BC
        DEC     HL
        JP      L02A1
		
;CheckEnoughVarSpace2
; То же, что и ниже, но C берется из следующей ячейки, откуда вызвана подпрограмма. Более эффективно, чем в Altair Basic
CheckEnoughVarSpace2:
	EX      (SP),HL
        LD      C,(HL)
        INC     HL
        EX      (SP),HL

;CheckEnoughVarSpace
;Checks that there is enough room for C*4 bytes on top of (VAR_TOP) before it intrudes on the stack. Probably varspace.
		
        PUSH    HL
        LD      HL,(VAR_TOP)
        LD      B,00H
        ADD     HL,BC
        ADD     HL,BC
        CALL    L02BB
        POP     HL
        RET     

;CheckEnoughMem
;Checks that HL is more than 32 bytes away from the stack pointer. If HL is within 32 bytes of the stack pointer then this function falls into OutOfMemory.

L02BB:  PUSH    DE
        EX      DE,HL
        LD      HL,0FFDAH
        ADD     HL,SP
        RST     20H
        EX      DE,HL
        POP     DE
        RET     NC

;Three common errors.
;Notice use of LXI trick.

L02C5:  LD      E,0CH
        JP      L02D8
		
L02CA:  LD      HL,(0233H)
        LD      (CURRENT_LINE),HL
		
SyntaxError:  LD      E,02H
		DB		01				; LD BC,...
L02D3:		LD      E,14H
		DB		01				; LD BC,
L02D6:        LD      E,00H

;Error
;Resets the stack, prints an error code (offset into error codes table is given in E), and stops program execution.
		
L02D8:  CALL    L03C2
        XOR     A
        LD      (l0217H),A
        CALL    L07DC
        LD      HL,01AAH
        LD      D,A
        LD      A,3FH
        RST     18H
        ADD     HL,DE
        LD      A,(HL)
        RST     18H
        RST     10H
        RST     18H
        LD      HL, szError
L02F1:  CALL    PrintString
        LD      HL, (CURRENT_LINE)
        LD      A,H
        AND     L
        INC     A
        CALL    NZ, PrintIN

;
; Main
; Here's where a BASIC programmer in 1975 spent most of their time : typing at an "OK" prompt, one line at a time. A line of input would either be exec'd immediately (eg "PRINT 2+2"), or it would be a line of a program to be RUN later. Program lines would be prefixed with a line number. The code below looks for that line number, and jumps ahead to Exec if it's not there.
;

Main:
	XOR		A
	LD		(l0217H),A			; Включаем вывод на экран
	LD		HL,0FFFFH			; Сбрасываем текущую выполняемую строку
	LD		(CURRENT_LINE),HL

	LD		HL,szOK				; Выводим приглашение
	CALL		PrintString

GetNonBlankLine:
	CALL	InputLine			; Считываем строку с клавиатуры
	RST		10H					; Считываем первый символ из буфера. Флаг переноса =1, если это цифра
	INC		A					; Проверяем на пустую строку. Инкремент/декремент не сбрасывает флаг переноса.
	DEC		A
	JP		Z, GetNonBlankLine	; Снова вводим строку, если пустая

	PUSH	AF					; Сохраняем флаг переноса
	CALL	LineNumberFromStr	; Получаем номер строки в DE
	PUSH	DE					; Запоминаем номер строки
	CALL	Tokenize			; Запускаем токенизатор. В C возвращается длина токенизированной строки, а в А = 0
	LD		B,A					; Теперь BC=длина строки
	POP		DE					; Восстанавливаем номер строки
	POP		AF					; Восстанавлливаем флаг переноса
	JP		NC, Exec			; Если у нас строка без номера, то сразу исполняем

;StoreProgramLine
;Here's where a program line has been typed, which we now need to store in program memory.

StoreProgramLine:
        PUSH    DE
        PUSH    BC
        RST     10H
        PUSH    AF
        CALL    L0385
        PUSH    BC
        JP      NC,L0341
        EX      DE,HL
        LD      HL,(VAR_BASE)
L0333:  LD      A,(DE)
        LD      (BC),A
        INC     BC
        INC     DE
        RST     20H
        JP      NC,L0333
        LD      H,B
        LD      L,C
        INC     HL
        LD      (VAR_BASE),HL
L0341:  POP     DE
        POP     AF
        JP      Z,L0368
        LD      HL,(VAR_BASE)
        EX      (SP),HL
        POP     BC
        ADD     HL,BC
        PUSH    HL
        CALL    L029B
        POP     HL
        LD      (VAR_BASE),HL
        EX      DE,HL
        LD      (HL),H
        INC     HL
        INC     HL
        POP     DE
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,01CFH
L0360:  LD      A,(DE)
        LD      (HL),A
        INC     HL
        INC     DE
        OR      A
        JP      NZ,L0360
L0368:  CALL    L03A9
        INC     HL
L036C:  LD      D,H
        LD      E,L
        LD      A,(HL)
        INC     HL
        OR      (HL)
        JP      Z,GetNonBlankLine
        INC     HL
        INC     HL
        INC     HL
        XOR     A
L0378:  CP      (HL)
        INC     HL
        JP      NZ,L0378
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        EX      DE,HL
        JP      L036C

;FindProgramLine
;Given a line number in DE, this function returns the address of that progam line in BC. If the line doesn't exist, then BC points to the next line's address, ie where the line could be inserted. Carry flag is set if the line exists, otherwise carry reset.
		
L0385:  LD      HL,(PROGRAM_BASE)
L0388:  LD      B,H
        LD      C,L
        LD      A,(HL)
        INC     HL
        OR      (HL)
        DEC     HL
        RET     Z

        PUSH    BC
        RST     30H
        RST     30H
        POP     HL
        RST     20H
        POP     HL
        POP     BC
        CCF     
        RET     Z

        CCF     
        RET     NC

        JP      L0388
		
;New
;Keyword NEW. Writes the null line number to the bottom of program storage (ie an empty program), updates pointer to variables storage,
; and falls into RUN which just happens to do the rest of the work NEW needs to do.

	ORG	039Dh
New:		
        RET     NZ

L039E:  LD      HL,(PROGRAM_BASE)
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (VAR_BASE),HL

;ResetAll
;Resets everything.
		
L03A9:  LD      HL,(PROGRAM_BASE)
        DEC     HL
L03AD:  LD      (0237H),HL
        LD      HL,(021BH)
        LD      (022FH),HL
        CALL    L05DB
        LD      HL,(VAR_BASE)
        LD      (VAR_ARRAY_BASE),HL
        LD      (VAR_TOP),HL
L03C2:  POP     BC
        LD      HL,(0241H)
        LD      SP,HL
        LD      HL,021FH
        LD      (021DH),HL
        LD      HL,0000H
        PUSH    HL
        LD      (023FH),HL
        LD      HL,(0237H)
        XOR     A
        LD      (0235H),A
        PUSH    BC
        RET     

;InputLineWith'?'
;Gets a line of input at a '? ' prompt.

L03DD:  LD      A,3FH
        RST     18H
        LD      A,20H
        RST     18H
        JP      InputLine
		
Tokenize:  XOR     A
        LD      (021AH),A
		
;Tokenize
;Tokenises LINE_BUFFER, replacing keywords with their IDs. On exit, C holds the length of the tokenised line plus a few bytes to make it a complete program line.

        LD      C,05H
        LD      DE,LINE_BUFFER
L03EF:  LD      A,(HL)
        CP      ' '
        JP      Z,L0439
        LD      B,A
        CP      '"'
        JP      Z,L0459
        OR      A
        JP      Z,Exit
        LD      A,(021AH)
        OR      A
        LD      B,A
        LD      A,(HL)
        JP      NZ,L0439
        CP      3FH
        LD      A,95H
        JP      Z,L0439
        LD      A,(HL)
        CP      30H
        JP      C,L041A
        CP      3CH
        JP      C,L0439
L041A:  PUSH    DE
        LD      DE,KEYWORDS-1
        PUSH    HL
        LD      A,0D7H
        INC     DE
L0422:  LD      A,(DE)
        AND     7FH
        JP      Z,0436h
        CP      (HL)
        JP      NZ,L0460
        LD      A,(DE)
        OR      A
        JP      P,0420h
        POP     AF
        LD      A,B
        OR      80H
        JP      P,7EE1h
        POP     DE
L0439:  INC     HL
        LD      (DE),A
        INC     DE
        INC     C
        SUB     3AH
        JP      Z,L0447
        CP      49H
        JP      NZ,L044A
L0447:  LD      (021AH),A
L044A:  SUB     54H
        JP      NZ,L03EF
        LD      B,A
L0450:  LD      A,(HL)
        OR      A
        JP      Z,Exit
        CP      B
        JP      Z,L0439
L0459:  INC     HL
	LD      (DE),A
        INC     C
        INC     DE
        JP      L0450
	
L0460:  POP     HL
        PUSH    HL
        INC     B
        EX      DE,HL
NextKwLoop:
	OR      (HL)
        INC     HL
        JP      P,NextKwLoop
        EX      DE,HL
        JP      L0422
	
Exit:	LD      HL,01CEH
        LD      (DE),A
        INC     DE
        LD      (DE),A
        INC     DE
        LD      (DE),A
        RET     

;InputLine
;Gets a line of input into LINE_BUFFER.

L0476:  DEC     B
        DEC     HL
        RST     18H
        JP      NZ,L0485
L047C:  RST     18H
        CALL    L07DC
InputLine:
	LD      HL,01CFH
        LD      B,01H
L0485:  CALL    L04D8
        CP      08H
        JP      Z,L0476
        CP      0DH
        JP      Z,L07D7
        CP      18H
        JP      Z,L047C
        CP      7FH
        JP      NC,L0485
        CP      01H
        JP      C,L0485
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        LD      C,A
        LD      A,B
        CP      48H
        LD      A,07H
        JP      NC,L04B3
        LD      A,C
        LD      (HL),C
        INC     HL
        INC     B
L04B3:  RST     18H
        JP      L0485
		
;; этот кусок не как в альтаире		
		
OutChar_tail:
	JP      NZ,L0DC4
        POP     AF
        PUSH    AF
        CP      20H
        JP      C,L04CD
        LD      A,(TERMINAL_X)
;;

;1.6 Terminal I/O
;OutChar_tail
;Prints a character to the terminal. On entry, the char to be printed is on the stack and A holds TERMINAL_X. If the current line is up to the maximum width then we print a new line and update the terminal position. Then we print the character - to do this we loop until the device is ready to receive a char and then write it out.

        CP      48H
        CALL    Z,L07DC
        INC     A
        LD      (TERMINAL_X),A
L04CD:  POP     AF
        PUSH    BC
        LD      C,A
        PUSH    AF
        CALL    0F809h
        POP     AF
        POP     BC
        NOP     
        RET     
		
;InputChar
;Gets one char of input from the user.		

L04D8:  CALL    0F803h
        CP      1FH
        JP      Z,0F800h
        NOP     
        AND     7FH
        CP      0FH
        RET     NZ

        LD      A,(l0217H)
        CPL     
        LD      (l0217H),A
        RET     

;1.7 LIST Handler
;List
;Lists the program. As the stored program is in tokenised form (ie keywords are represented with single byte numeric IDs) LIST is more complex than a simple memory dump. When it meets a keyword ID it looks it up in the keywords table and prints it.

	ORG	04EEH
List:
        CALL    LineNumberFromStr
        RET     NZ

        POP     BC
        CALL    L0385
        PUSH    BC
L04F7:  POP     HL
        RST     30H
L04F9:  POP     BC
        LD      A,B
        OR      C
        JP      Z,Main
        CALL    L05E5
        PUSH    BC
        CALL    L07DC
        RST     30H
        EX      (SP),HL
        CALL    L1465
        LD      A,20H
L050D:  POP     HL
L050E:  RST     18H
        LD      A,(HL)
        OR      A
        INC     HL
        JP      Z,L04F7
        JP      P,L050E
        SUB     7FH
        LD      C,A
        PUSH    HL
        LD      DE, KEYWORDS
L051F:  PUSH    DE
L0520:  LD      A,(DE)
        INC     DE
        OR      A
        JP      P,L0520
        DEC     C
        POP     HL
        JP      NZ,L051F
L052B:  LD      A,(HL)
        OR      A
        JP      M,L050D
        RST     18H
        INC     HL
        JP      L052B

;1.8 FOR Handler
;For
;Although FOR indicates the beginning of a program loop, the handler only gets called the once. Subsequent iterations of the loop return to the following statement or program line, not the FOR statement itself.

	ORG	0535H
For:		
        LD      A,64H
        LD      (0235H),A
        CALL    L0710
        EX      (SP),HL
        CALL    L027A
        POP     DE
        JP      NZ,L0547
        ADD     HL,BC
        LD      SP,HL
L0547:  EX      DE,HL
        CALL    CheckEnoughVarSpace2
        DB	08H
        PUSH    HL
        CALL    L06F9
        EX      (SP),HL
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        EX      (SP),HL
        CALL    L0969
        RST     SyntaxCheck
        DB	9Eh
        CALL    L0966
        PUSH    HL
        CALL    L130D
        POP     HL
        PUSH    BC
        PUSH    DE
        LD      BC,8100H
        LD      D,C
        LD      E,D
        LD      A,(HL)
        CP      0A3H
        LD      A,01H
        JP      NZ,L057C
        RST     10H
        CALL    L0966
        PUSH    HL
        CALL    L130D
        POP     HL
        RST     28H
L057C:  PUSH    BC
        PUSH    DE
        PUSH    AF
        INC     SP
        
		PUSH    HL
		
		
        LD      HL,(0237H)
        EX      (SP),HL
L0585:  LD      B,81H
        PUSH    BC
        INC     SP
		
		
;		
;1.9 Execution
;ExecNext
;Having exec'd one statement, this block moves on to the next statement in the line or the next line if there are no more statements on the current line.
;

ExecNext:		
L0589:  CALL    0F812h
        NOP     
        CALL    NZ,L05EA
        LD      (0237H),HL
        LD      A,(HL)
        CP      3AH
        JP      Z,Exec
        OR      A
        JP      NZ,SyntaxError
        INC     HL
        LD      A,(HL)
        INC     HL
        OR      (HL)
        INC     HL
        JP      Z,L05F6
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      (CURRENT_LINE),HL
        EX      DE,HL
		
;Exec
;Executes a statement of BASIC code pointed to by HL.

		
Exec:	RST     10H
        LD      DE,L0589
        PUSH    DE
L05B2:  RET     Z

L05B3:  SUB     80H
        JP      C,L0710
        CP      1DH
        JP      NC,SyntaxError
        RLCA    
        LD      C,A
        LD      B,00H
        EX      DE,HL
        LD      HL,0170H
        ADD     HL,BC
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        PUSH    BC
        EX      DE,HL
		
L05CB:  INC     HL
        LD      A,(HL)
        CP      3AH
        RET     NC


;1.10 More Utility Functions
;NextChar_tail

NextChar_tail:
	CP      20H
        JP      Z,L05CB
        CP      30H
        CCF     
        INC     A
        DEC     A
        RET     

;Restore
;Resets the data pointer to just before the start of the program.

	ORG	05DBh
Restore:
L05DB:  EX      DE,HL
        LD      HL,(PROGRAM_BASE)
        DEC     HL
L05E0:  LD      (DATA_PROG_PTR),HL
        EX      DE,HL
        RET     

;TestBreakKey
;Apparently the Altair had a 'break' key, to break program execution. This little function tests to see if the terminal input device is ready, and returns if it isn't. If it is ready (ie user has pressed a key) then it reads the char from the device, compares it to the code for the break key (0x03) and jumps to Stop. Since the first instruction at Stop is RNZ, this will return at once if the user pressed some other key.

L05E5:  CALL    0F812h
        NOP     
        RET     Z

L05EA:  CALL    L04D8
        CP      03H
	
	ORG	05efh
Stop:
        RET     NZ

        OR      0C0H
        LD      (0237H),HL
L05F5:  POP     BC
L05F6:  PUSH    AF
        LD      HL,(CURRENT_LINE)
        LD      A,L
        AND     H
        INC     A
        JP      Z,L0609
        LD      (023DH),HL
        LD      HL,(0237H)
        LD      (023FH),HL
L0609:  XOR     A
        LD      (l0217H),A
        POP     AF
        LD      HL, szStop
        JP      NZ,L02F1
        JP      Main

	ORG	0617H
Cont:	
        RET     NZ

        LD      E,20H
        LD      HL,(023FH)
        LD      A,H
        OR      L
        JP      Z,L02D8
        EX      DE,HL
        LD      HL,(023DH)
        LD      (CURRENT_LINE),HL
        EX      DE,HL
        RET     


        CALL    L0FB9
        RET     NZ

        INC     A
        CP      48H
        JP      NC,L065C
        LD      (TERMINAL_Y),A
        RET     
;
;CharIsAlpha
;If character pointed to by HL is alphabetic, the carry flag is reset otherwise set.
;
CharIsAlpha:
L0639:  LD      A,(HL)
        CP      41H
        RET     C

        CP      5BH
        CCF     
        RET     


;GetSubscript
;Gets the subscript of an array variable encountered in an expression or a DIM declaration. The subscript is returned as a positive integer in CDE.

L0641:  RST     10H
L0642:  CALL    L0966
L0645:  RST     28H
        JP      M,L065C
L0649:  LD      A,(FACCUM+3)
        CP      90H
        JP      C,L1367
        LD      BC,9080H
        LD      DE,0000H
        CALL    L133C
        LD      D,C
        RET     Z

L065C:  LD      E,08H
        JP      L02D8
		
;1.11 Jumping to Program Lines
;LineNumberFromStr
;Gets a line number from a string pointer. The string pointer is passed in in HL, and the integer result is returned in DE. Leading spaces are skipped over, and it returns on finding the first non-digit. The largest possible line number is 65529 - it syntax errors out if the value of the first four digits is more then 6552.

;One interesting feature of this function is that it returns with Z set if it found a valid number (or the string was empty), or NZ if the string didn't lead with a number.
		
LineNumberFromStr:
	DEC     HL
L0662:  LD      DE,0000H
L0665:  RST     10H
        RET     NC

        PUSH    HL
        PUSH    AF
        LD      HL,1998H
        RST     20H
        JP      C,SyntaxError
        LD      H,D
        LD      L,E
        ADD     HL,DE
        ADD     HL,HL
        ADD     HL,DE
        ADD     HL,HL
        POP     AF
        SUB     30H
        LD      E,A
        LD      D,00H
        ADD     HL,DE
        EX      DE,HL
        POP     HL
        JP      L0665
	
	ORG	0682H
Clear:
        JP      Z,L03AD
        CALL    L0642
        DEC     HL
        RST     10H
        RET     NZ

        PUSH    HL
        LD      HL,(021BH)
        LD      A,L
        SUB     E
        LD      E,A
        LD      A,H
        SBC     A,D
        LD      D,A
        JP      C,SyntaxError
        LD      HL,(VAR_BASE)
        LD      BC,0028H
        ADD     HL,BC
        RST     20H
        JP      NC,L02C5
        EX      DE,HL
        LD      (0241H),HL
        POP     HL
        JP      L03AD
;;;		
	ORG	06ABH
Run:
        JP      Z,L03A9
        CALL    L03AD
        LD      BC,L0589
        JP      L06C6
		
	ORG	06B7H
Gosub:
        CALL    CheckEnoughVarSpace2
        DB	03h
        POP     BC
        PUSH    HL
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        EX      (SP),HL
        LD      D,8CH
        PUSH    DE
        INC     SP
L06C6:  PUSH    BC

	ORG	06C7H
Goto:
L06C7:  CALL    LineNumberFromStr
        CALL    Rem
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        RST     20H
        POP     HL
        INC     HL
        CALL    C,L0388
        CALL    NC,L0385
        LD      H,B
        LD      L,C
        DEC     HL
        RET     C

        LD      E,0EH
        JP      L02D8
		
		
;		Return
;Returns program execution to the statement following the last GOSUB. Information about where to return to is kept on the stack in a flow struct (see notes).

	ORG	06e3h
Return:
        RET     NZ
        LD      D,0FFH
        CALL    L027A
        LD      SP,HL
        CP      8CH
        LD      E,04H
        JP      NZ,L02D8
        POP     HL
        LD      (CURRENT_LINE),HL
        LD      HL,L0589
        EX      (SP),HL
		
;Safe to fall into FindNextStatement, since we're already at the end of the line!...

 

;FindNextStatement
;Finds the end of the statement or the end of the program line.

;BUG: There is an interesting bug in this block, although it's harmless as by luck it's impossible to see it. The byte at 04F7 is 0x10, an illegal instruction, which is in turn followed by a NOP. This illegal instruction is almost certainly supposed to be 0x0E, so as to become the two-byte instruction MOV C,00. If this were the case it would make perfect sense as the loop reads ahead until it finds a null byte terminating the line or whatever the C register is loaded with.

;04F7 is jumped to in two places - it is the REM handler, and also when an IF statement's condition evals to false and the rest of the line needs to be skipped. Luckily in both these cases, C just happens to be loaded with a byte that cannot occur in the program so the null byte marking the end of the line is found as expected.

Data:
L06F9:  DB		01H
		DB		3AH			;LD      BC,..3AH
Rem:		
		DB		0EH		;LD		C, 0
        NOP     
        LD      B,00H
L06FF:  LD      A,C
        LD      C,B
        LD      B,A
L0702:  LD      A,(HL)
        OR      A
        RET     Z

        CP      B
        RET     Z

        INC     HL
        CP      22H
        JP      Z,L06FF
        JP      L0702

;1.12 Assigning Variables
;Let
;Assigns a value to a variable.

L0710:  CALL    0B1Ah
        RST     SyntaxCheck
        DB	0ACH
        LD      A,(0219H)
        PUSH    AF
        PUSH    DE
        CALL    L0975
        EX      (SP),HL
        LD      (0237H),HL
        POP     DE
        POP     AF
        PUSH    DE
        RRA     
        CALL    L096B
        JP      Z,L0755
L072B:  PUSH    HL
        LD      HL,(FACCUM)
        PUSH    HL
        INC     HL
        INC     HL
        RST     30H
        POP     DE
        LD      HL,(0241H)
        RST     20H
        POP     DE
        JP      NC,L0745
        LD      HL,(VAR_BASE)
        RST     20H
        LD      L,E
        LD      H,D
        CALL    C,L0D2F
L0745:  LD      A,(DE)
        PUSH    AF
        XOR     A
        LD      (DE),A
        CALL    L0EC5
        POP     AF
        LD      (HL),A
        EX      DE,HL
        POP     HL
        CALL    L131C
        POP     HL
        RET     

L0755:  PUSH    HL
        CALL    L1319
        POP     DE
        POP     HL
        RET     

;1.13 IF Keyword Handler
;If
;Evaluates a condition. A condition has three mandatory parts : a left-hand side expression, a comparison operator, and a right-hand side expression. Examples are 'A=2', 'B<=4' and so on.

;The comparison operator is one or more of the three operators '>', '=', and '<'. Since these three operators can appear more than once, and in any order, the code does something rather clever to convert them to a single 'comparison operator value'. This value has bit 0 set if '>' is present, bit 1 for '=', and bit 2 for '<'. Thus the comparison operators '<=' and '=<' are both 6, likewise '>=' and '=>' are both 3, and '<>' is 5

;You can therefore get away with stupid operators such as '>>>>>' (value 1, the same as a single '>') and '>=<' (value 7), the latter being particularly dense as it causes the condition to always evaluate to true.

	ORG	075Ch
On:
        CALL    L0FB9
        LD      A,(HL)
        LD      B,A
        CP      8CH
        JP      Z,L0769
        RST     SyntaxCheck
        DB	088h
        DEC     HL
L0769:  LD      C,E
L076A:  DEC     C
        LD      A,B
        JP      Z,L05B3
        CALL    L0662
        CP      2CH
        RET     NZ

        JP      L076A

	ORG	0778h
If:
        CALL    L0975
        LD      A,(HL)
        CP      88H
        JP      Z,L0784
        RST     SyntaxCheck
        DB	0A1h
        DEC     HL
L0784:  RST     28H
        JP      Z,Rem
        RST     10H
        JP      C,L06C7
        JP      L05B2
		
;1.14 Printing
;Print
;Prints something! It can be an empty line, a single expression/literal, or multiple expressions/literals seperated by tabulation directives 
;(comma, semi-colon, or the TAB keyword).
		
        DEC     HL
L0790:  RST     10H

	ORG	0791H
Print:
        JP      Z,L07DC
L0794:  RET     Z

        CP      9DH
        JP      Z,L0808
        CP      9FH
        JP      Z,L0808
        PUSH    HL
        CP      2CH
        JP      Z,L07F4
        CP      3BH
        JP      Z,L0828
        POP     BC
        CALL    L0975
        DEC     HL
        PUSH    HL
        LD      A,(0219H)
        OR      A
        JP      NZ,L07D0
        CALL    L1470
        CALL    L0D4F
        LD      HL,(FACCUM)
        LD      A,(TERMINAL_X)
        ADD     A,(HL)
        CP      40H
        CALL    NC,L07DC
        CALL    L0D96
        LD      A,20H
        RST     18H
        XOR     A
L07D0:  CALL    NZ,L0D96
        POP     HL
        JP      L0790
		
;TerminateInput
;HL points to just beyond the last byte of a line of user input. Here we write a null byte to terminate it, reset HL to point to the start of the input line buffer, then fall into NewLine.
		
L07D7:  LD      (HL),00H
        LD      HL,01CEH
		
;NewLine
;Prints carriage return + line feed, plus a series of nulls which was probably due to some peculiarity of the teletypes of the day.
		
L07DC:  LD      A,0DH
        LD      (TERMINAL_X),A
        RST     18H
        LD      A,0AH
        RST     18H
L07E5:  LD      A,(TERMINAL_Y)
L07E8:  DEC     A
        LD      (TERMINAL_X),A
        RET     Z

        PUSH    AF
        XOR     A
        RST     18H
        POP     AF
        JP      L07E8
		

;ToNextTabBreak
;Calculate how many spaces are needed to get us to the next tab-break then jump to PrintSpaces to do it.
		
L07F4:  LD      A,(TERMINAL_X)
        CP      30H
        CALL    NC,L07DC
        JP      NC,L0828
L07FF:  SUB     0EH
        JP      NC,L07FF
        CPL     
        JP      L081F
		
;Tab
;Tabulation. The TAB keyword takes an integer argument denoting the absolute column to print spaces up to.
		
Tab:
L0808:  PUSH    AF
        CALL    0FB8h
        RST     SyntaxCheck
        DB	29h
        DEC     HL
        POP     AF
        CP      9FH
        PUSH    HL
        LD      A,E
        JP      Z,L0820
        LD      A,(TERMINAL_X)
        CPL     
        ADD     A,E
        JP      NC,L0828
PrintSpaces:	
L081F:  INC     A

L0820:  LD      B,A
        LD      A,20H
PrintSpaceLoop:
L0823:  RST     18H
        DEC     B
        JP      NZ,L0823
ExitTab:
L0828:  POP     HL
        RST     10H
        JP      L0794

szRepeat:
	DB	3Fh, 70h, 6Fh, 77h, 74h, 6Fh, 72h, 69h, 74h, 65h, 20h, 77h, 77h, 6Fh, 64h, 0A0h, 0Dh, 0Ah, 00	; "?ПОВТОРИТЕ ВВОД "
		
L0840:  LD      A,(0236H)
        OR      A
        JP      NZ,L02CA
        POP     BC
        LD      HL, szRepeat
        CALL    PrintString
        LD      HL,(0237H)
        RET     

	ORG	0852h
Input:
        CP      22H
        LD      A,00H
        LD      (l0217H),A
        JP      NZ,L0866
        CALL    L0D50
        RST     SyntaxCheck
        DB	3bh
        PUSH    HL
        CALL    L0D96
        POP     HL
L0866:  PUSH    HL
        CALL    L0D02
        CALL    L03DD
        INC     HL
        LD      A,(HL)
        OR      A
        DEC     HL
        POP     BC
        JP      Z,L05F5
        PUSH    BC
        JP      087Eh

	ORG	0879h
Read:
        PUSH    HL
        LD      HL,(DATA_PROG_PTR)
        OR      0AFH
        LD      (0236H),A
        EX      (SP),HL
        LD      BC,2CCFH
        CALL    0B1Ah
        EX      (SP),HL
        PUSH    DE
        LD      A,(HL)
        CP      2CH
        JP      Z,L089E
        LD      A,(0236H)
        OR      A
        JP      NZ,L08FB
        LD      A,3FH
        RST     18H
        CALL    L03DD
L089E:  LD      A,(0219H)
        OR      A
        JP      Z,L08BE
        RST     10H
        LD      D,A
        LD      B,A
        CP      22H
        JP      Z,L08B2
        LD      D,3AH
        LD      B,2CH
        DEC     HL
L08B2:  CALL    L0D53
        EX      DE,HL
        LD      HL,08C7H
        EX      (SP),HL
        PUSH    DE
        JP      L072B
L08BE:  RST     10H
        CALL    L13C6
        EX      (SP),HL
        CALL    L1319
        POP     HL
        DEC     HL
        RST     10H
        JP      Z,L08D1
        CP      2CH
        JP      NZ,L0840
L08D1:  EX      (SP),HL
        DEC     HL
        RST     10H
        JP      NZ,0884h
        POP     DE
        LD      A,(0236H)
        OR      A
        EX      DE,HL
        JP      NZ,L05E0
        OR      (HL)
        LD      HL, szOverflow
        PUSH    DE
        CALL    NZ,PrintString
        POP     HL
        RET     

szOverflow:
	DB	3Fh, 6Ch, 69h, 7Bh, 6Eh, 69h, 65h, 20h, 64h, 61h, 6Eh, 6Eh, 79h, 0E5h, 0Dh, 0Ah, 00h	; "?ЛИШНИЕ ДАННЫЕ"

L08FB:  CALL    L06F9
        OR      A
        JP      NZ,L0914
        INC     HL
        RST     30H
        LD      A,C
        OR      B
        LD      E,06H
        JP      Z,L02D8
        POP     BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      (0233H),HL
        EX      DE,HL
L0914:  RST     10H
        CP      83H
        JP      NZ,L08FB
        JP      L089E

;1.16 NEXT Handler
;Next
;The NEXT keyword is followed by the name of the FOR variable, so firstly we get the address of that variable into DE.

	ORG	091Dh
Next:
        LD      DE,0000H
L0920:  CALL    NZ,0B1Ah
        LD      (0237H),HL
        CALL    L027A
        JP      NZ,L02D6
        LD      SP,HL
        PUSH    DE
        LD      A,(HL)
        INC     HL
        PUSH    AF
        PUSH    DE
        CALL    L12FF
        EX      (SP),HL
        PUSH    HL
        CALL    L1073
        POP     HL
        CALL    L1319
        POP     HL
        CALL    L1310
        PUSH    HL
        CALL    L133C
        POP     HL
        POP     BC
        SUB     B
        CALL    L1310
        JP      Z,L0958
        EX      DE,HL
        LD      (CURRENT_LINE),HL
        LD      L,C
        LD      H,B
        JP      L0585
L0958:  LD      SP,HL
        LD      HL,(0237H)
        LD      A,(HL)
        CP      2CH
        JP      NZ,L0589
        RST     10H
        CALL    L0920
L0966:  CALL    L0975
L0969:  OR      37H
L096B:  LD      A,(0219H)
        ADC     A,A
        RET     PE

        LD      E,18H
        JP      L02D8
	
L0975:  DEC     HL
        LD      D,00H
L0978:  PUSH    DE
        CALL    CheckEnoughVarSpace2
	DB	01h
	CALL	09e5h
        LD      (0239H),HL
L0983:  LD      HL,(0239H)
        POP     BC
        LD      A,B
        CP      78H
        CALL    NC,L0969
        LD      A,(HL)
        LD      D,00H
L0990:  SUB     0ABH
        JP      C,L09AA
        CP      03H
        JP      NC,L09AA
        CP      01H
        RLA     
        XOR     D
        CP      D
        LD      D,A
        JP      C,SyntaxError
        LD      (0231H),HL
        RST     10H
        JP      L0990
	
L09AA:  LD      A,D
        OR      A
        JP      NZ,L0A9E
        LD      A,(HL)
        LD      (0231H),HL
        SUB     0A4H
        RET     C

        CP      07H
        RET     NC

        LD      E,A
        LD      A,(0219H)
        DEC     A
        OR      E
        LD      A,E
        JP      Z,L0E77
        RLCA    
        ADD     A,E
        LD      E,A
        LD      HL,0073H
        ADD     HL,DE
        LD      A,B
        LD      D,(HL)
        CP      D
        RET     NC

        INC     HL
        CALL    L0969
L09D2:  PUSH    BC
        LD      BC,L0983
        PUSH    BC
        LD      B,E
        LD      C,D
        CALL    L12F2
        LD      E,B
        LD      D,C
        RST     30H
        LD      HL,(0231H)
        JP      L0978
	
L09E5:  XOR     A
L09E6:  LD      (0219H),A
        RST     10H
        JP      C,L13C6
        CALL    L0639
        JP      NC,L0A2F
        CP      0A4H
        JP      Z,L09E5
        CP      2EH
        JP      Z,L13C6
        CP      0A5H
        JP      Z,L0A1E
        CP      22H
        JP      Z,L0D50
        CP      0A2H
        JP      Z,L0AF9
        CP      0A0H
        JP      Z,L0CCD
        SUB     0AEH
        JP      NC,L0A40
L0A16:  RST     SyntaxCheck
        DB	28H
	CALL	L0975
        RST     SyntaxCheck
L0A1C:  DB	29h
        RET     

L0A1E:  LD      D,7DH
        CALL    L0978
        LD      HL,(0239H)
        PUSH    HL
        CALL    L12EA
        CALL    L0969
        POP     HL
        RET     

L0A2F:  CALL    0B1Ah
        PUSH    HL
        EX      DE,HL
        LD      (FACCUM),HL
        LD      A,(0219H)
        OR      A
        CALL    Z,L12FF
        POP     HL
        RET     

L0A40:  LD      B,00H
        RLCA    
        LD      C,A
        PUSH    BC
        RST     10H
        LD      A,C
        CP      29H
        JP      C,L0A65
        RST     SyntaxCheck
	DB	28h
	CALL	L0975

        RST     SyntaxCheck
        DB	2ch
        CALL    096Ah
        EX      DE,HL
        LD      HL,(FACCUM)
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        CALL    L0FB9
        EX      DE,HL
        EX      (SP),HL
        JP      L0A6D
	
L0A65:  CALL    L0A16
        EX      (SP),HL
        LD      DE,0A2AH
        PUSH    DE
L0A6D:  LD      BC,0043H
        ADD     HL,BC
        LD      C,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,C
        JP      (HL)


	ORG	0A76h
FOr:
	DB	0F6h	;OR 0AFH

	ORG	0A77h
FAnd:
	XOR	A	; AFh
        PUSH    AF
        CALL    L0969
        CALL    L0649
        POP     AF
        EX      DE,HL
        POP     BC
        EX      (SP),HL
        EX      DE,HL
        CALL    L1302
        PUSH    AF
        CALL    L0649
        POP     AF
        POP     BC
        LD      A,C
        LD      HL,L0C9B
        JP      NZ,L0A99
        AND     E
        LD      C,A
        LD      A,B
        AND     D
        JP      (HL)
L0A99:  OR      E
        LD      C,A
        LD      A,B
        OR      D
        JP      (HL)
L0A9E:  LD      HL,0AB0H
        LD      A,(0219H)
        RRA     
        LD      A,D
        RLA     
        LD      E,A
        LD      D,64H
        LD      A,B
        CP      D
        RET     NC

        JP      L09D2
        OR      D
        LD      A,(BC)
        LD      A,C
        OR      A
        RRA     
        POP     BC
        POP     DE
        PUSH    AF
        CALL    L096B
        LD      HL,0AEFH
        PUSH    HL
        JP      Z,L133C
        XOR     A
        LD      (0219H),A
        PUSH    DE
        CALL    L0EC1
        POP     DE
        RST     30H
        RST     30H
        CALL    L0EC5
        CALL    L1310
        POP     HL
        EX      (SP),HL
        LD      D,L
        POP     HL
L0AD7:  LD      A,E
        OR      D
        RET     Z

        LD      A,D
        OR      A
        CPL     
        RET     Z

        XOR     A
        CP      E
        INC     A
        RET     NC

        DEC     D
        DEC     E
        LD      A,(BC)
        CP      (HL)
        INC     HL
        INC     BC
        JP      Z,L0AD7
        CCF     
        JP      L12D0
	
        INC     A
        ADC     A,A
        POP     BC
        AND     B
        ADD     A,0FFH
        SBC     A,A
        JP      FCharToFloat
	
L0AF9:  LD      D,5AH
        CALL    L0978
        CALL    L0969
        CALL    L0649
        LD      A,E
        CPL     
        LD      C,A
        LD      A,D
        CPL     
        CALL    L0C9B
        POP     BC
        JP      L0983

;1.18 Variable Management
;Dim
;Declares an array. Note that the start of this function handler is some way down in the block (at 0716).

        DEC     HL
        RST     10H
        RET     Z

        RST     SyntaxCheck
        DB	2ch
	
	ORG	0B15H
Dim:
        LD      BC,0B10H
        PUSH    BC
        OR      0AFH
        LD      (0218H),A
        LD      B,(HL)
L0B1F:  CALL    L0639
        JP      C,SyntaxError
        XOR     A
        LD      C,A
        LD      (0219H),A
        RST     10H
        JP      C,L0B34
        CALL    L0639
        JP      C,L0B3F
L0B34:  LD      C,A
L0B35:  RST     10H
        JP      C,L0B35
        CALL    L0639
        JP      NC,L0B35
L0B3F:  SUB     24H
        JP      NZ,L0B4C
        INC     A
        LD      (0219H),A
        RRCA    
        ADD     A,C
        LD      C,A
        RST     10H
L0B4C:  LD      A,(0235H)
        ADD     A,(HL)
        CP      28H
        JP      Z,L0B9E
        XOR     A
        LD      (0235H),A
        PUSH    HL
        LD      HL,(VAR_ARRAY_BASE)
        EX      DE,HL
        LD      HL,(VAR_BASE)
L0B61:  RST     20H
        JP      Z,L0B78
        LD      A,C
        SUB     (HL)
        INC     HL
        JP      NZ,L0B6D
        LD      A,B
        SUB     (HL)
L0B6D:  INC     HL
        JP      Z,L0B9B
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        JP      L0B61

L0B78:  PUSH    BC
        LD      BC,0006H
        LD      HL,(VAR_TOP)
        PUSH    HL
        ADD     HL,BC
        POP     BC
        PUSH    HL
        CALL    L029B
        POP     HL
        LD      (VAR_TOP),HL
        LD      H,B
        LD      L,C
        LD      (VAR_ARRAY_BASE),HL
L0B8F:  DEC     HL
        LD      (HL),00H
        RST     20H
        JP      NZ,L0B8F
        POP     DE
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
L0B9B:  EX      DE,HL
        POP     HL
        RET     

L0B9E:  PUSH    HL
        LD      HL,(0218H)
        EX      (SP),HL
        LD      D,00H
L0BA5:  PUSH    DE
        PUSH    BC
        CALL    L0641
        POP     BC
        POP     AF
        EX      DE,HL
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        INC     A
        LD      D,A
        LD      A,(HL)
        CP      2CH
        JP      Z,L0BA5
        RST     SyntaxCheck
        DB	29h
        LD      (0239H),HL
        POP     HL
        LD      (0218H),HL
        PUSH    DE
        LD      HL,(VAR_ARRAY_BASE)
        LD      A,19H
        EX      DE,HL
        LD      HL,(VAR_TOP)
        EX      DE,HL
        RST     20H
        JP      Z,L0BF3
        LD      A,(HL)
        CP      C
        INC     HL
        JP      NZ,L0BD8
        LD      A,(HL)
        CP      B
L0BD8:  INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        JP      NZ,0BC6h
        LD      A,(0218H)
        OR      A
        LD      E,12H
        JP      NZ,L02D8
        POP     AF
        CP      (HL)
        JP      Z,L0C52
L0BEE:  LD      E,10H
        JP      L02D8
L0BF3:  LD      DE,0004H
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        POP     AF
        LD      (0C01H),A
        CALL    CheckEnoughVarSpace2
        DB	0e9h
        LD      (0231H),HL
        INC     HL
        INC     HL
        LD      B,C
        LD      (HL),B
        INC     HL
L0C0A:  LD      A,(0218H)
        OR      A
        LD      A,B
        LD      BC,000BH
        JP      Z,L0C17
        POP     BC
        INC     BC
L0C17:  LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        PUSH    AF
        PUSH    HL
        CALL    L13AB
        EX      DE,HL
        POP     HL
        POP     BC
        DEC     B
        JP      NZ,L0C0A
        LD      B,D
        LD      C,E
        EX      DE,HL
        ADD     HL,DE
        JP      C,L0BEE
        CALL    L02BB
        LD      (VAR_TOP),HL
L0C34:  DEC     HL
        LD      (HL),00H
        RST     20H
        JP      NZ,L0C34
        INC     BC
        LD      H,A
        LD      A,(0218H)
        OR      A
        LD      A,(0C01H)
        LD      L,A
        ADD     HL,HL
        ADD     HL,BC
        EX      DE,HL
        LD      HL,(0231H)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        JP      NZ,L0C74
L0C52:  INC     HL
        LD      BC,0000H
        LD      D,0E1H
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        EX      (SP),HL
        PUSH    AF
        RST     20H
        JP      NC,L0BEE
        PUSH    HL
        CALL    L13AB
        POP     DE
        ADD     HL,DE
        POP     AF
        DEC     A
        LD      B,H
        LD      C,L
        JP      NZ,0C57h
        ADD     HL,HL
        ADD     HL,HL
        POP     BC
        ADD     HL,BC
        EX      DE,HL
L0C74:  LD      HL,(0239H)
        DEC     HL
        RST     10H
        RET     

	ORG	0C7Ah
Fre:
        LD      HL,(VAR_TOP)
        EX      DE,HL
        LD      HL,0000H
        ADD     HL,SP
        LD      A,(0219H)
        OR      A
        JP      Z,L0C96
        CALL    L0EC1
        CALL    L0DD2
        LD      HL,(0241H)
        EX      DE,HL
        LD      HL,(022FH)
L0C96:  LD      A,L
        SUB     E
        LD      C,A
        LD      A,H
        SBC     A,D
L0C9B:  LD      B,C
L0C9C:  LD      D,B
        LD      E,00H
        LD      HL,0219H
        LD      (HL),E
        LD      B,90H
        JP      L12DA

	ORG	0CA8h
Pos:
        LD      A,(TERMINAL_X)
L0CAB:  LD      B,A
        XOR     A
        JP      L0C9C
	
	ORG	0CB0h
Def:
        CALL    L0D10
        LD      BC,L06F9
        PUSH    BC
        PUSH    DE
        CALL    L0D02
        RST     SyntaxCheck
	DB	28h
	CALL	0b1ah
        CALL    L0969
        RST     SyntaxCheck
        DB	29h
        RST     SyntaxCheck
        DB	0ach
        LD      B,H
        LD      C,L
        EX      (SP),HL
        JP      L0CF9
	
L0CCD:  CALL    L0D10
        PUSH    DE
        CALL    L0A16
        CALL    L0969
        EX      (SP),HL
        RST     30H
        POP     DE
        RST     30H
        POP     HL
        RST     30H
        RST     30H
        DEC     HL
        DEC     HL
        DEC     HL
        DEC     HL
        PUSH    HL
        RST     20H
        PUSH    DE
        LD      E,22H
        JP      Z,L02D8
        CALL    L1319
        POP     HL
        CALL    L0966
        DEC     HL
        RST     10H
        JP      NZ,SyntaxError
        POP     HL
        POP     DE
        POP     BC
L0CF9:  LD      (HL),C
        INC     HL
        LD      (HL),B
L0CFC:  INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        RET     

L0D02:  PUSH    HL
        LD      HL,(CURRENT_LINE)
        INC     HL
        LD      A,H
        OR      L
        POP     HL
        RET     NZ

        LD      E,16H
        JP      L02D8
L0D10:  RST     SyntaxCheck
        DB	0a0h
        LD      A,80H
        LD      (0235H),A
        OR      (HL)
        LD      B,A
        CALL    L0B1F
        JP      L0969
	
	ORG	0d1fh
Str:
        CALL    L0969
        CALL    L1470
        CALL    L0D4F
        CALL    L0EC1
        LD      BC,0F10H
        PUSH    BC
L0D2F:  LD      A,(HL)
        INC     HL
        INC     HL
        PUSH    HL
        CALL    L0DAA
        POP     HL
        RST     30H
        POP     BC
        CALL    L0D46
        PUSH    HL
        LD      L,A
        CALL    L0EB4
        POP     DE
        RET     

L0D43:  CALL    L0DAA
L0D46:  LD      HL,022BH
        PUSH    HL
        LD      (HL),A
        INC     HL
        JP      L0CFC
L0D4F:  DEC     HL
L0D50:  LD      B,22H
        LD      D,B
L0D53:  PUSH    HL
        LD      C,0FFH
L0D56:  INC     HL
        LD      A,(HL)
        INC     C
        OR      A
        JP      Z,L0D65
        CP      D
        JP      Z,L0D65
        CP      B
        JP      NZ,L0D56
L0D65:  CP      22H
        CALL    Z,L05CB
        EX      (SP),HL
        INC     HL
        EX      DE,HL
        LD      A,C
        CALL    L0D46
        RST     20H
        CALL    NC,L0D2F
L0D75:  LD      DE,022BH
        LD      HL,(021DH)
        LD      (FACCUM),HL
        LD      A,01H
        LD      (0219H),A
        CALL    L131C
        RST     20H
        LD      E,1EH
        JP      Z,L02D8
        LD      (021DH),HL
        POP     HL
        LD      A,(HL)
        RET     

        INC     HL
PrintString:
	CALL    L0D4F
L0D96:  CALL    L0EC1
        CALL    L1310
        INC     E
L0D9D:  DEC     E
        RET     Z

        LD      A,(BC)
        RST     18H
        CP      0DH
        CALL    Z,L07E5
        INC     BC
        JP      L0D9D
		
L0DAA:  OR      A
        LD      C,0F1H
        PUSH    AF
        LD      HL,(0241H)
        EX      DE,HL
        LD      HL,(022FH)
        CPL     
        LD      C,A
        LD      B,0FFH
        ADD     HL,BC
        INC     HL
        RST     20H
        JP      C,L0DC6
        LD      (022FH),HL
        INC     HL
        EX      DE,HL
L0DC4:  POP     AF
        RET     

L0DC6:  POP     AF
        LD      E,1AH
        JP      Z,L02D8
        CP      A
        PUSH    AF
        LD      BC,0DACH
        PUSH    BC
L0DD2:  LD      HL,(021BH)
L0DD5:  LD      (022FH),HL
        LD      HL,0000H
        PUSH    HL
        LD      HL,(0241H)
        PUSH    HL
        LD      HL,021FH
        EX      DE,HL
        LD      HL,(021DH)
        EX      DE,HL
        RST     20H
        LD      BC,0DE3H
        JP      NZ,L0E2F
        LD      HL,(VAR_BASE)
L0DF2:  EX      DE,HL
        LD      HL,(VAR_ARRAY_BASE)
        EX      DE,HL
        RST     20H
        JP      Z,L0E06
        LD      A,(HL)
        INC     HL
        INC     HL
        OR      A
        CALL    L0E32
        JP      L0DF2
L0E05:  POP     BC
L0E06:  EX      DE,HL
        LD      HL,(VAR_TOP)
        EX      DE,HL
        RST     20H
        JP      Z,L0E52
        CALL    L1310
        LD      A,E
        PUSH    HL
        ADD     HL,BC
        OR      A
        JP      P,L0E05
        LD      (0231H),HL
        POP     HL
        LD      C,(HL)
        LD      B,00H
        ADD     HL,BC
        ADD     HL,BC
        INC     HL
        EX      DE,HL
        LD      HL,(0231H)
        EX      DE,HL
        RST     20H
        JP      Z,L0E06
        LD      BC,0E23H
L0E2F:  PUSH    BC
        OR      80H
L0E32:  RST     30H
        RST     30H
        POP     DE
        POP     BC
        RET     P

        LD      A,C
        OR      A
        RET     Z

        LD      B,H
        LD      C,L
        LD      HL,(022FH)
        RST     20H
        LD      H,B
        LD      L,C
        RET     C

        POP     HL
        EX      (SP),HL
        RST     20H
        EX      (SP),HL
        PUSH    HL
        LD      H,B
        LD      L,C
        RET     NC

        POP     BC
        POP     AF
        POP     AF
        PUSH    HL
        PUSH    DE
        PUSH    BC
        RET     

L0E52:  POP     DE
        POP     HL
        LD      A,L
        OR      H
        RET     Z

        DEC     HL
        LD      B,(HL)
        DEC     HL
        LD      C,(HL)
        PUSH    HL
        DEC     HL
        DEC     HL
        LD      L,(HL)
        LD      H,00H
        ADD     HL,BC
        LD      D,B
        LD      E,C
        DEC     HL
        LD      B,H
        LD      C,L
        LD      HL,(022FH)
        CALL    L029E
        POP     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        LD      L,C
        LD      H,B
        DEC     HL
        JP      L0DD5
L0E77:  PUSH    BC
        PUSH    HL
        LD      HL,(FACCUM)
        EX      (SP),HL
        CALL    L09E5
        EX      (SP),HL
        CALL    096Ah
        LD      A,(HL)
        PUSH    HL
        LD      HL,(FACCUM)
        PUSH    HL
        ADD     A,(HL)
        LD      E,1CH
        JP      C,L02D8
        CALL    L0D43
        POP     DE
        CALL    L0EC5
        EX      (SP),HL
        CALL    L0EC4
        PUSH    HL
        LD      HL,(022DH)
        EX      DE,HL
        CALL    L0EAE
        CALL    L0EAE
        LD      HL,0986H
        EX      (SP),HL
        PUSH    HL
        JP      L0D75
L0EAE:  POP     HL
        EX      (SP),HL
        RST     30H
        RST     30H
        POP     BC
        POP     HL
L0EB4:  INC     L
L0EB5:  DEC     L
        RET     Z

        LD      A,(BC)
        LD      (DE),A
        INC     BC
        INC     DE
        JP      L0EB5
L0EBE:  CALL    096Ah
L0EC1:  LD      HL,(FACCUM)
L0EC4:  EX      DE,HL
L0EC5:  LD      HL,(021DH)
        DEC     HL
        LD      B,(HL)
        DEC     HL
        LD      C,(HL)
        DEC     HL
        DEC     HL
        RST     20H
        EX      DE,HL
        RET     NZ

        LD      (021DH),HL
        PUSH    DE
        LD      D,B
        LD      E,C
        DEC     DE
        LD      C,(HL)
        LD      HL,(022FH)
        RST     20H
        JP      NZ,L0EE5
        LD      B,A
        ADD     HL,BC
        LD      (022FH),HL
L0EE5:  POP     HL
        RET     

	ORG	0EE7h
Len:
        LD      BC,L0CAB
        PUSH    BC
L0EEB:  CALL    L0EBE
        XOR     A
        LD      D,A
        LD      (0219H),A
        LD      A,(HL)
        OR      A
        RET     

	ORG	0ef6h
Asc:
        CALL    L0EEB
        JP      Z,L065C
        INC     HL
        INC     HL
        RST     30H
        POP     HL
        LD      A,(HL)
        JP      L0CAB
	
	ORG	0f04h
Chr:
        LD      A,01H
        CALL    L0D43
        CALL    L0FBC
        LD      HL,(022DH)
        LD      (HL),E
        POP     BC
        JP      L0D75

	ORG	0f14h
Left:
        CALL    L0F9F
        XOR     A
L0F18:  EX      (SP),HL
        LD      C,A
        PUSH    HL
        LD      A,(HL)
        CP      B
        JP      C,0F22h
        LD      A,B
        LD      DE,000EH
        PUSH    BC
        CALL    L0DAA
        POP     BC
        POP     HL
        PUSH    HL
        INC     HL
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,B
        LD      B,00H
        ADD     HL,BC
        LD      B,H
        LD      C,L
        CALL    L0D46
        LD      L,A
        CALL    L0EB4
        POP     DE
        CALL    L0EC5
        JP      L0D75
	
	ORG	0f44h
Right:
        CALL    L0F9F
        POP     DE
        PUSH    DE
        LD      A,(DE)
        SUB     B
        JP      L0F18

	ORG	0f4eh
Mid:
        EX      DE,HL
        LD      A,(HL)
        CALL    L0FA2
        PUSH    BC
        LD      E,0FFH
        CP      29H
        JP      Z,L0F60
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
L0F60:  RST     SyntaxCheck
        DB	29h
        POP     AF
        EX      (SP),HL
        LD      BC,0F1AH
        PUSH    BC
        DEC     A
        CP      (HL)
        LD      B,00H
        RET     NC

        LD      C,A
        LD      A,(HL)
        SUB     C
        CP      E
        LD      B,A
        RET     C

        LD      B,E
        RET     

	ORG	0f75h
Inp:
        CALL    L0FBC
        LD      (0F7CH),A
        IN      A,(00H)
        JP      L0CAB

	ORG	0F80h
Out:
        CALL    L0FAC
        OUT     (00H),A
        RET     

        CALL    L0FAC
        PUSH    AF
        LD      E,00H
        DEC     HL
        RST     10H
        JP      Z,L0F96
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
L0F96:  POP     BC
L0F97:  IN      A,(00H)
        XOR     E
        AND     B
        JP      Z,L0F97
        RET     

L0F9F:  EX      DE,HL
        RST     SyntaxCheck
        DB	29h
L0FA2:  POP     BC
        POP     DE
        PUSH    BC
        LD      B,E
        INC     B
        DEC     B
        JP      Z,L065C
        RET     

L0FAC:  CALL    L0FB9
        LD      (0F98H),A
        LD      (0F84H),A
        RST     SyntaxCheck
        DB	2ch
        LD      B,0D7H
L0FB9:  CALL    L0966
L0FBC:  CALL    L0645
        LD      A,D
        OR      A
        JP      NZ,L065C
        DEC     HL
        RST     10H
        LD      A,E
        RET     

	ORG	0Fc8H
Val:
        CALL    L0EEB
        JP      Z,L10E8
        LD      E,A
        INC     HL
        INC     HL
        RST     30H
        LD      H,B
        LD      L,C
        ADD     HL,DE
        LD      B,(HL)
        LD      (HL),D
        EX      (SP),HL
        PUSH    BC
        LD      A,(HL)
        CALL    L13C6
        POP     BC
        POP     HL
        LD      (HL),B
        RET     

L0FE1:  CALL    0F806h
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        RET     

L0FEB:  CALL    L0FEE
L0FEE:  PUSH    AF
        POP     AF
        PUSH    BC
        LD      C,A
        PUSH    AF
        CALL    0F80CH
        POP     AF
        POP     BC
        NOP     
        RET     

        PUSH    HL
        LD      A,0D3H
L0FFD:  CALL    L0FEE
        CALL    L0FEB
        LD      A,(HL)
        CALL    L0FEE
        LD      HL,(PROGRAM_BASE)
        EX      DE,HL
        LD      HL,(VAR_BASE)
L100E:  LD      A,(DE)
        INC     DE
        CALL    L0FEE
        RST     20H
        JP      NZ,L100E
        CALL    L0FEB
        POP     HL
        RST     10H
        RET     

        LD      (FACCUM),A
        CALL    L039E
L1023:  LD      B,03H
L1025:  CALL    L0FE1
        CP      0D3H
        JP      NZ,L1023
        DEC     B
        JP      NZ,L1025
        LD      HL,FACCUM
        CALL    L0FE1
        CP      (HL)
        JP      NZ,L1023
        LD      HL,(PROGRAM_BASE)
L103E:  LD      B,04H
L1040:  CALL    L0FE1
        LD      (HL),A
        CALL    L02BB
        LD      A,(HL)
        OR      A
        INC     HL
        JP      NZ,L103E
        DEC     B
        JP      NZ,L1040
L1051:  LD      (VAR_BASE),HL
        LD      HL,026BH
        CALL    PrintString
        JP      L0368
        CALL    L0645
        LD      A,(DE)
        JP      L0CAB
        CALL    L0642
L1067:  PUSH    DE
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
        POP     DE
        LD      (DE),A
        RET     

L1070:  LD      HL,1539H
L1073:  CALL    L1310
        JP      L1082
	
L1079:  CALL    L1310
        DB	21h			;LD      HL,...
	
	ORG	107dh
FSub:
	POP	BC
	POP	DE
L107F:  CALL    L12EA
L1082:  LD      A,B
        OR      A
        RET     Z

        LD      A,(FACCUM+3)
        OR      A
        JP      Z,L1302
        SUB     B
        JP      NC,L109C
        CPL     
        INC     A
        EX      DE,HL
        CALL    L12F2
        EX      DE,HL
        CALL    L1302
        POP     BC
        POP     DE
L109C:  CP      19H
        RET     NC

        PUSH    AF
        CALL    L1327
        LD      H,A
        POP     AF
        CALL    L1149
        OR      H
        LD      HL,FACCUM
        JP      P,L10C2
        CALL    L1129
        JP      NC,L1108
        INC     HL
        INC     (HL)
        JP      Z,L1124
        LD      L,01H
        CALL    L115F
        JP      L1108
L10C2:  XOR     A
        SUB     B
        LD      B,A
        LD      A,(HL)
        SBC     A,E
        LD      E,A
        INC     HL
        LD      A,(HL)
        SBC     A,D
        LD      D,A
        INC     HL
        LD      A,(HL)
        SBC     A,C
        LD      C,A
L10D0:  CALL    C,L1135
L10D3:  LD      L,B
        LD      H,E
        XOR     A
L10D6:  LD      B,A
        LD      A,C
        OR      A
        JP      NZ,L10F5
        LD      C,D
        LD      D,H
        LD      H,L
        LD      L,A
        LD      A,B
        SUB     08H
        CP      0E0H
        JP      NZ,L10D6
L10E8:  XOR     A
L10E9:  LD      (FACCUM+3),A
        RET     

L10ED:  DEC     B
        ADD     HL,HL
        LD      A,D
        RLA     
        LD      D,A
        LD      A,C
        ADC     A,A
        LD      C,A
L10F5:  JP      P,L10ED
        LD      A,B
        LD      E,H
        LD      B,L
        OR      A
        JP      Z,L1108
        LD      HL,FACCUM+3
        ADD     A,(HL)
        LD      (HL),A
        JP      NC,L10E8
        RET     Z

L1108:  LD      A,B
L1109:  LD      HL,FACCUM+3
        OR      A
        CALL    M,L111A
        LD      B,(HL)
        INC     HL
        LD      A,(HL)
        AND     80H
        XOR     C
        LD      C,A
        JP      L1302
L111A:  INC     E
        RET     NZ

        INC     D
        RET     NZ

        INC     C
        RET     NZ

        LD      C,80H
        INC     (HL)
        RET     NZ

L1124:  LD      E,0AH
        JP      L02D8
L1129:  LD      A,(HL)
        ADD     A,E
        LD      E,A
        INC     HL
        LD      A,(HL)
        ADC     A,D
        LD      D,A
        INC     HL
        LD      A,(HL)
        ADC     A,C
        LD      C,A
        RET     

L1135:  LD      HL,0251H
        LD      A,(HL)
        CPL     
        LD      (HL),A
        XOR     A
        LD      L,A
        SUB     B
        LD      B,A
        LD      A,L
        SBC     A,E
        LD      E,A
        LD      A,L
        SBC     A,D
        LD      D,A
        LD      A,L
        SBC     A,C
        LD      C,A
        RET     

L1149:  LD      B,00H
L114B:  SUB     08H
        JP      C,L1158
        LD      B,E
        LD      E,D
        LD      D,C
        LD      C,00H
        JP      L114B
L1158:  ADD     A,09H
        LD      L,A
L115B:  XOR     A
        DEC     L
        RET     Z

        LD      A,C
L115F:  RRA     
        LD      C,A
        LD      A,D
        RRA     
        LD      D,A
        LD      A,E
        RRA     
        LD      E,A
        LD      A,B
        RRA     
        LD      B,A
        JP      L115B
        NOP     
        NOP     
        NOP     
        ADD     A,C
        INC     BC
        XOR     D
        LD      D,(HL)
        ADD     HL,DE
        ADD     A,B
        POP     AF
        LD      (8076H),HL
        LD      B,L
        XOR     D
        db	38h, 82h
	ORG	117eh
Log:
L117E:  RST     28H
        JP      PE,L065C
        LD      HL,FACCUM+3
        LD      A,(HL)
        LD      BC,8035H
        LD      DE,04F3H
        SUB     B
        PUSH    AF
        LD      (HL),B
        PUSH    DE
        PUSH    BC
        CALL    L1082
        POP     BC
        POP     DE
        INC     B
        CALL    L121A
        LD      HL,116DH
        CALL    L1079
        LD      HL,1171H
        CALL    L15FA
        LD      BC,8080H
        LD      DE,0000H
        CALL    L1082
        POP     AF
        CALL    L1446
L11B3:  LD      BC,8031H
        LD      DE,7218H
        DB	21h		;LD      HL,...
	
	ORG	11BAh
FMul:
	POP	BC
	POP	DE
L11BC:  RST     28H
        RET     Z

        LD      L,00H
        CALL    L128A
        LD      A,C
        LD      (11F3H),A
        EX      DE,HL
        LD      (11EEH),HL
        LD      BC,0000H
        LD      D,B
        LD      E,B
        LD      HL,L10D3
        PUSH    HL
        LD      HL,11DCH
        PUSH    HL
        PUSH    HL
        LD      HL,FACCUM
        LD      A,(HL)
        INC     HL
        OR      A
        JP      Z,L1207
        PUSH    HL
        EX      DE,HL
        LD      E,08H
L11E6:  RRA     
        LD      D,A
        LD      A,C
        JP      NC,L11F4
        PUSH    DE
        LD      DE,0000H
        ADD     HL,DE
        POP     DE
        ADC     A,00H
L11F4:  RRA     
        LD      C,A
        LD      A,H
        RRA     
        LD      H,A
        LD      A,L
        RRA     
        LD      L,A
        LD      A,B
        RRA     
        LD      B,A
        DEC     E
        LD      A,D
        JP      NZ,L11E6
        EX      DE,HL
L1205:  POP     HL
        RET     

L1207:  LD      B,E
        LD      E,D
        LD      D,C
        LD      C,A
        RET     

L120C:  CALL    L12F2
        LD      BC,8420H
        LD      DE,0000H
        CALL    L1302
	
	ORG	1218H
FDiv:
L1218:  POP     BC
        POP     DE
L121A:  RST     28H
        JP      Z,L02D3
        LD      L,0FFH
        CALL    L128A
        INC     (HL)
        INC     (HL)
        DEC     HL
        LD      A,(HL)
        LD      (1249H),A
        DEC     HL
        LD      A,(HL)
        LD      (1245H),A
        DEC     HL
        LD      A,(HL)
        LD      (1241H),A
        LD      B,C
        EX      DE,HL
        XOR     A
        LD      C,A
        LD      D,A
        LD      E,A
        LD      (124CH),A
L123D:  PUSH    HL
        PUSH    BC
        LD      A,L
        SUB     00H
        LD      L,A
        LD      A,H
        SBC     A,00H
        LD      H,A
        LD      A,B
        SBC     A,00H
        LD      B,A
        LD      A,00H
        SBC     A,00H
        CCF     
        JP      NC,125Ah
        LD      (124CH),A
        POP     AF
        POP     AF
        SCF     
        JP      NC,0E1C1h
        LD      A,C
        INC     A
        DEC     A
        RRA     
        JP      M,L1109
        RLA     
        LD      A,E
        RLA     
        LD      E,A
        LD      A,D
        RLA     
        LD      D,A
        LD      A,C
        RLA     
        LD      C,A
        ADD     HL,HL
        LD      A,B
        RLA     
        LD      B,A
        LD      A,(124CH)
        RLA     
        LD      (124CH),A
        LD      A,C
        OR      D
        OR      E
        JP      NZ,L123D
        PUSH    HL
        LD      HL,FACCUM+3
        DEC     (HL)
        POP     HL
        JP      NZ,L123D
        JP      L1124
L128A:  LD      A,B
        OR      A
        JP      Z,L12AC
        LD      A,L
        LD      HL,FACCUM+3
        XOR     (HL)
        ADD     A,B
        LD      B,A
        RRA     
        XOR     B
        LD      A,B
        JP      P,L12AB
        ADD     A,80H
        LD      (HL),A
        JP      Z,L1205
        CALL    L1327
        LD      (HL),A
        DEC     HL
        RET     

L12A8:  RST     28H
        CPL     
        POP     HL
L12AB:  OR      A
L12AC:  POP     HL
        JP      P,L10E8
        JP      L1124
L12B3:  CALL    L130D
        LD      A,B
        OR      A
        RET     Z

        ADD     A,02H
        JP      C,L1124
        LD      B,A
        CALL    L1082
        LD      HL,FACCUM+3
        INC     (HL)
        RET     NZ

        JP      L1124


;A group of functions for testing and changing the sign of an fp number.

;FTestSign_tail
;When FACCUM is non-zero, RST FTestSign jumps here to get the sign as an integer : 0x01 for positive, 0xFF for negative.
	ORG	12cah

FTestSign_tail:
	LD	A,(024FH)
	CP	2FH

;SignToInt
;Converts the sign byte in A to 0x01 for positive, 0xFF for negative.

        RLA     
L12D0:  SBC     A,A
        RET     NZ

        INC     A
        RET     

;Sgn
;Returns an integer that indicates FACCUM's sign. We do this by a simple call to FTestSign which gets the answer in A, then fall into FCharToFloat to get that answer back into FACCUM.
;
;Get FACCUM's sign in A. A will be 0x01 for positive, 0 for zero, and 0xFF for negative.
	ORG	12D4H

Sgn:	RST     28H

;FCharToFloat
;Converts the signed byte in A to a floating-point number in FACCUM..

FCharToFloat:
	LD      B,88H
        LD      DE,0000H
L12DA:  LD      HL,FACCUM+3
        LD      C,A
        LD      (HL),B
        LD      B,00H
        INC     HL
        LD      (HL),80H
        RLA     
        JP      L10D0

;Abs
;FACCUM = |FACCUM|.
;
;Return if FACCUM is already positive, otherwise fall into FNegate to make it positive.
	ORG	12e8h
Abs:
        RST     28H
        RET     P

L12EA:  LD      HL,024FH
        LD      A,(HL)
        XOR     80H
        LD      (HL),A
        RET     

L12F2:  EX      DE,HL
        LD      HL,(FACCUM)
        EX      (SP),HL
        PUSH    HL
        LD      HL,(024FH)
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        RET     

L12FF:  CALL    L1310
L1302:  EX      DE,HL
        LD      (FACCUM),HL
        LD      H,B
        LD      L,C
        LD      (024FH),HL
        EX      DE,HL
        RET     

L130D:  LD      HL,FACCUM
L1310:  LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
L1317:  INC     HL
        RET     

L1319:  LD      DE,FACCUM
L131C:  LD      B,04H
L131E:  LD      A,(DE)
        LD      (HL),A
        INC     DE
        INC     HL
        DEC     B
        JP      NZ,L131E
        RET     

L1327:  LD      HL,024FH
        LD      A,(HL)
        RLCA    
        SCF     
        RRA     
        LD      (HL),A
        CCF     
        RRA     
        INC     HL
        INC     HL
        LD      (HL),A
        LD      A,C
        RLCA    
        SCF     
        RRA     
        LD      C,A
        RRA     
        XOR     (HL)
        RET     

L133C:  LD      A,B
        OR      A
        JP      Z, 0028h
        LD      HL,12CEH
        PUSH    HL
        RST     28H
        LD      A,C
        RET     Z

        LD      HL,024FH
        XOR     (HL)
        LD      A,C
        RET     M

        CALL    L1354
        RRA     
        XOR     C
        RET     

L1354:  INC     HL
        LD      A,B
        CP      (HL)
        RET     NZ

        DEC     HL
        LD      A,C
        CP      (HL)
        RET     NZ

        DEC     HL
        LD      A,D
        CP      (HL)
        RET     NZ

        DEC     HL
        LD      A,E
        SUB     (HL)
        RET     NZ

        POP     HL
        POP     HL
        RET     

L1367:  LD      B,A
        LD      C,A
        LD      D,A
        LD      E,A
        OR      A
        RET     Z

        PUSH    HL
        CALL    L130D
        CALL    L1327
        XOR     (HL)
        LD      H,A
        CALL    M,L138B
        LD      A,98H
        SUB     B
        CALL    L1149
        LD      A,H
        RLA     
        CALL    C,L111A
        LD      B,00H
        CALL    C,L1135
        POP     HL
        RET     

L138B:  DEC     DE
        LD      A,D
        AND     E
        INC     A
        RET     NZ

        DEC     C
        RET     

;Int
;Removes the fractional part of FACCUM.

;If FACCUM's exponent is >= 2^24, then it's too big to hold any fractional part - it is already an integer, so we just return.

	ORG	1392h
Int:
L1392:  LD      HL,FACCUM+3
        LD      A,(HL)
        CP      98H
        LD      A,(FACCUM)
        RET     NC

        LD      A,(HL)
        CALL    L1367
        LD      (HL),98H
        LD      A,E
        PUSH    AF
        LD      A,C
        RLA     
        CALL    L10D0
        POP     AF
        RET     

L13AB:  LD      HL,0000H
        LD      A,B
        OR      C
        RET     Z

        LD      A,10H
L13B3:  ADD     HL,HL
        JP      C,L0BEE
        EX      DE,HL
        ADD     HL,HL
        EX      DE,HL
        JP      NC,L13C1
        ADD     HL,BC
        JP      C,L0BEE
L13C1:  DEC     A
        JP      NZ,L13B3
        RET     

L13C6:  CP      2DH
        PUSH    AF
        JP      Z,L13D2
        CP      2BH
        JP      Z,L13D2
        DEC     HL
L13D2:  CALL    L10E8
        LD      B,A
        LD      D,A
        LD      E,A
        CPL     
        LD      C,A
L13DA:  RST     10H
        JP      C,L142F
        CP      2EH
        JP      Z,L140A
        CP      45H
        JP      NZ,L140E
        RST     10H
        PUSH    HL
        LD      HL,L13FE
        EX      (SP),HL
        DEC     D
        CP      0A5H
        RET     Z

        CP      2DH
        RET     Z

        INC     D
        CP      2BH
        RET     Z

        CP      0A4H
        RET     Z

        POP     AF
        DEC     HL
L13FE:  RST     10H
        JP      C,L1451
        INC     D
        JP      NZ,L140E
        XOR     A
        SUB     E
        LD      E,A
        INC     C
L140A:  INC     C
        JP      Z,L13DA
L140E:  PUSH    HL
        LD      A,E
        SUB     B
L1411:  CALL    P,L1427
        JP      P,L141D
        PUSH    AF
        CALL    L120C
        POP     AF
        INC     A
L141D:  JP      NZ,L1411
        POP     DE
        POP     AF
        CALL    Z,L12EA
        EX      DE,HL
        RET     

L1427:  RET     Z

L1428:  PUSH    AF
        CALL    L12B3
        POP     AF
        DEC     A
        RET     

L142F:  PUSH    DE
        LD      D,A
        LD      A,B
        ADC     A,C
        LD      B,A
        PUSH    BC
        PUSH    HL
        PUSH    DE
        CALL    L12B3
        POP     AF
        SUB     30H
        CALL    L1446
        POP     HL
        POP     BC
        POP     DE
        JP      L13DA
L1446:  CALL    L12F2
        CALL    FCharToFloat
	
	ORG	144ch
FAdd:
        POP     BC
        POP     DE
        JP      L1082
	
L1451:  LD      A,E
        RLCA    
        RLCA    
        ADD     A,E
        RLCA    
        ADD     A,(HL)
        SUB     30H
        LD      E,A
        JP      L13FE
	
;2.10 Printing Numbers
;Functions for printing floating-point numbers.

;PrintIN
;Prints "IN " and falls into PrintInt. Used by the error handling code to print stuff like "?SN ERROR IN 50".
	
		
PrintIN:  PUSH    HL
        LD      HL,0266H
        CALL    PrintString
        POP     HL
		
		
L1465:  EX      DE,HL
        XOR     A
        LD      B,98H
        CALL    L12DA
        LD      HL,0D92H
        PUSH    HL
L1470:  LD      HL,0252H
        PUSH    HL
        RST     28H
        LD      (HL),20H
        JP      P,L147C
        LD      (HL),2DH
L147C:  INC     HL
        LD      (HL),30H
        JP      Z,L1525
        PUSH    HL
        CALL    M,L12EA
        XOR     A
        PUSH    AF
        CALL    L152B
L148B:  LD      BC,9143H
        LD      DE,4FF8H
        CALL    L133C
        JP      PO,L14A8
        POP     AF
        CALL    L1428
        PUSH    AF
        JP      L148B
L149F:  CALL    L120C
        POP     AF
        INC     A
        PUSH    AF
        CALL    L152B
L14A8:  CALL    L1070
        INC     A
        CALL    L1367
        CALL    L1302
        LD      BC,0206H
        POP     AF
        ADD     A,C
        JP      M,L14C3
        CP      07H
        JP      NC,L14C3
        INC     A
        LD      B,A
        LD      A,01H
L14C3:  DEC     A
        POP     HL
        PUSH    AF
        LD      DE,153DH
L14C9:  DEC     B
        LD      (HL),2EH
        CALL    Z,L1317
        PUSH    BC
        PUSH    HL
        PUSH    DE
        CALL    L130D
        POP     HL
        LD      B,2FH
L14D8:  INC     B
        LD      A,E
        SUB     (HL)
        LD      E,A
        INC     HL
        LD      A,D
        SBC     A,(HL)
        LD      D,A
        INC     HL
        LD      A,C
        SBC     A,(HL)
        LD      C,A
        DEC     HL
        DEC     HL
        JP      NC,L14D8
        CALL    L1129
        INC     HL
        CALL    L1302
        EX      DE,HL
        POP     HL
        LD      (HL),B
        INC     HL
        POP     BC
        DEC     C
        JP      NZ,L14C9
        DEC     B
        JP      Z,L1509
L14FD:  DEC     HL
        LD      A,(HL)
        CP      30H
        JP      Z,L14FD
        CP      2EH
        CALL    NZ,L1317
L1509:  POP     AF
        JP      Z,L1528
        LD      (HL),45H
        INC     HL
        LD      (HL),2BH
        JP      P,L1519
        LD      (HL),2DH
        CPL     
        INC     A
L1519:  LD      B,2FH
L151B:  INC     B
        SUB     0AH
        JP      NC,L151B
        ADD     A,3AH
        INC     HL
        LD      (HL),B
L1525:  INC     HL
        LD      (HL),A
        INC     HL
L1528:  LD      (HL),C
        POP     HL
        RET     

L152B:  LD      BC,9474H
        LD      DE,23F7H
        CALL    L133C
        POP     HL
        JP      PO,L149F
        JP      (HL)
        NOP     
        NOP     
        NOP     
        ADD     A,B
        AND     B
        ADD     A,(HL)
        LD      BC,2710H
        NOP     
        RET     PE

        INC     BC
        NOP     
        LD      H,H
        NOP     
        NOP     
        LD      A,(BC)
        NOP     
        NOP     
        LD      BC,0000H
L154F:  LD      HL,L12EA
        EX      (SP),HL
        JP      (HL)
	
	ORG	1554h
Sqr:
        CALL    L12F2
        LD      HL,1539H
        CALL    L12FF

	ORG	155dh
FPower:
        POP     BC
        POP     DE
        RST     28H
        JP      Z,L1599
        LD      A,B
        OR      A
        JP      Z,L10E9
        PUSH    DE
        PUSH    BC
        LD      A,C
        OR      7FH
        CALL    L130D
        JP      P,L1581
        PUSH    DE
        PUSH    BC
        CALL    L1392
        POP     BC
        POP     DE
        PUSH    AF
        CALL    L133C
        POP     HL
        LD      A,H
        RRA     
L1581:  POP     HL
        LD      (024FH),HL
        POP     HL
        LD      (FACCUM),HL
        CALL    C,L154F
        CALL    Z,L12EA
        PUSH    DE
        PUSH    BC
        CALL    L117E
        POP     BC
        POP     DE
        CALL    L11BC
	
	ORG	1599h
Exp:
L1599:  CALL    L12F2
        LD      BC,8138H
        LD      DE,0AA3BH
        CALL    L11BC
        LD      A,(FACCUM+3)
        CP      88H
        JP      NC,L12A8
        CALL    L1392
        ADD     A,80H
        ADD     A,02H
        JP      C,L12A8
        PUSH    AF
        LD      HL,116DH
        CALL    L1073
        CALL    L11B3
        POP     AF
        POP     BC
        POP     DE
        PUSH    AF
        CALL    L107F
        CALL    L12EA
        LD      HL,15D9H
        CALL    L1609
        LD      DE,0000H
        POP     BC
        LD      C,D
        JP      L11BC
	
	DB	08h
        LD      B,B
        LD      L,94H
        LD      (HL),H
        LD      (HL),B
        LD      C,A
        LD      L,77H
        LD      L,(HL)
        LD      (BC),A
        ADC     A,B
        LD      A,D
        AND     0A0H
        LD      HL,(507CH)
        XOR     D
        XOR     D
        LD      A,(HL)
        RST     38H
        RST     38H
        LD      A,A
        LD      A,A
        NOP     
        NOP     
        ADD     A,B
        ADD     A,C
        NOP     
        NOP     
        NOP     
        ADD     A,C
	ORG	15fah
L15FA:  CALL    L12F2
        LD      DE,11BAH
        PUSH    DE
        PUSH    HL
        CALL    L130D
        CALL    L11BC
        POP     HL
L1609:  CALL    L12F2
        LD      A,(HL)
        INC     HL
        CALL    L12FF
        DB	06h		; LD      B,..
L1612:	POP	AF
        POP     BC
        POP     DE
        DEC     A
        RET     Z

        PUSH    DE
        PUSH    BC
        PUSH    AF
        PUSH    HL
        CALL    L11BC
        POP     HL
        CALL    L1310
        PUSH    HL
        CALL    L1082
        POP     HL
        JP      L1612

	ORG	162ah
Rnd:
	RST     28H
        JP      M,L1647
        LD      HL,165CH
        CALL    L12FF
        RET     Z

        LD      BC,9835H
        LD      DE,447AH
        CALL    L11BC
        LD      BC,6828H
        LD      DE,0B146H
        CALL    L1082
L1647:  CALL    L130D
        LD      A,E
        LD      E,C
        LD      C,A
        LD      (HL),80H
        DEC     HL
        LD      B,(HL)
        LD      (HL),80H
        CALL    L10D3
        LD      HL,165CH
        JP      L1319
	
        LD      D,D
        RST     00H
        LD      C,A
        ADD     A,B
	
	ORG	1660H
Cos:
L1660:  LD      HL,16A6H
        CALL    L1073
	ORG	1666h
Sin:
L1666:  CALL    L12F2
        LD      BC,8349H
        LD      DE,0FDBH
        CALL    L1302
        POP     BC
        POP     DE
        CALL    L121A
        CALL    L12F2
        CALL    L1392
        POP     BC
        POP     DE
        CALL    L107F
        LD      HL,16AAH
        CALL    L1079
        RST     28H
        SCF     
        JP      P,L1692
        CALL    L1070
        RST     28H
        OR      A
L1692:  PUSH    AF
        CALL    P,L12EA
        LD      HL,16AAH
        CALL    L1073
        POP     AF
        CALL    NC,L12EA
        LD      HL,16AEH
        JP      L15FA
        IN      A,(0FH)
        LD      C,C
        ADD     A,C
        NOP     
        NOP     
        NOP     
        LD      A,A
        DEC     B
        CP      D
        RST     10H
        LD      E,86H
        LD      H,H
        LD      H,99H
        ADD     A,A
        LD      E,B
        INC     (HL)
        INC     HL
        ADD     A,A
        RET     PO

        LD      E,L
        AND     L
        ADD     A,(HL)
        JP      C,490Fh
        ADD     A,E

	ORG	16c3h	
Tan:
        CALL    L12F2
        CALL    L1666
        POP     BC
        POP     HL
        CALL    L12F2
        EX      DE,HL
        CALL    L1302
        CALL    L1660
        JP      L1218

	ORG	16D8h
Atn:
        RST     28H
        CALL    M,L154F
        CALL    M,L12EA
        LD      A,(FACCUM+3)
        CP      81H
        JP      C,L16F3
        LD      BC,8100H
        LD      D,C
        LD      E,C
        CALL    L121A
        LD      HL,L1079
        PUSH    HL
L16F3:  LD      HL,16FDH
        CALL    L15FA
        LD      HL,16A6H
        RET     

        ADD     HL,BC
        LD      C,D
        RST     10H
        DEC     SP
        LD      A,B
        LD      (BC),A
        LD      L,(HL)
        ADD     A,H
        LD      A,E
        CP      0C1H
        CPL     
        LD      A,H
        LD      (HL),H
        LD      SP,7D9AH
        ADD     A,H
        DEC     A
        LD      E,D
        LD      A,L
        RET     Z

        LD      A,A
        SUB     C
        LD      A,(HL)
        CALL    PO,4CBBh
        LD      A,(HL)
        LD      L,H
        XOR     D
        XOR     D
        LD      A,A
        NOP     
        NOP     
        NOP     
        ADD     A,C
        NOP     
        NOP     
	
	ORG	1724h
Peek:	
        RST     28H
        CALL    L0649
        LD      A,(DE)
        JP      L0CAB
	
	ORG	172CH
Poke:
        CALL    L0966
        RST     28H
        CALL    L0649
        JP      L1067
	
	ORG	1736h
Usr:
        RST     28H
        CALL    L0649
        EX      DE,HL
        CALL    L1741
        JP      L0CAB
	
L1741:  JP      (HL)

; Выставляем маркер конца программы (по описанию должно быть 2 байта...)
Init:	XOR     A
        LD      (2200H),A

		; Приветственное сообщение
        LD      HL, szHello
L1749:  LD      A,(HL)
        OR      A			; CP 0
        JP      Z,Main
        LD      C,(HL)
        INC     HL
        CALL    0F809h
        JP      L1749
		
szHello:		DB		1Fh, 0Dh, 0Ah, 2Ah, 4Dh, 69h, 6Bh, 72h, 4Fh, 2Fh
			DB		38h, 30h, 2Ah, 20h, 42h, 41h, 53h, 49h, 43h, 00h

	ORG	176ah
Cur:
L176A:  CALL    L0FB9
        LD      (1957H),A
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
        LD      (1958H),A
        CP      20H
        JP      NC,L065C
        LD      A,(1957H)
        CP      40H
        JP      NC,L065C
        PUSH    HL
        LD      HL,(0F75AH)
        LD      DE,0F801H
        ADD     HL,DE
        LD      (HL),00H
        LD      HL,0EFC0H
L1792:  LD      DE,0FFC0H
        LD      A,(1958H)
        OR      A
L1799:  JP      Z,L17A1
        ADD     HL,DE
        DEC     A
        JP      L1799
L17A1:  LD      D,00H
        LD      A,(1957H)
        LD      E,A
        ADD     HL,DE
        LD      (0F75AH),HL
        LD      DE,0F801H
        ADD     HL,DE
        LD      (HL),80H
        POP     HL
        RET     

	ORG	17B3H
Cls:
        PUSH    HL
        LD      HL,0E800H
        LD      DE,1A00H
L17BA:  XOR     A
        LD      (HL),A
        INC     HL
        LD      (DE),A
        INC     DE
        LD      A,D
        CP      22H
        JP      NZ,L17BA
        POP     HL
        RET     

	ORG	17C7H
Plot:
        CALL    L0FB9
        LD      (1954H),A
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
        LD      (1955H),A
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
        LD      (1956H),A
L17DD:  LD      A,(1954H)
        CP      80H
        JP      NC,L065C
        LD      A,(1955H)
        CP      40H
        JP      NC,L065C
        LD      D,A
        LD      A,3FH
        SUB     D
        LD      (1955H),A
        PUSH    HL
        XOR     A
        LD      A,(1954H)
        RRA     
        LD      E,A
        LD      A,C
        RRA     
        LD      C,A
        LD      A,(1955H)
        RRA     
        LD      D,A
        LD      A,C
        RLA     
        RLA     
        LD      C,A
        LD      A,D
        RRCA    
        RRCA    
        LD      D,A
        AND     0C0H
        OR      E
        LD      E,A
        LD      A,D
        AND     07H
        LD      D,A
        LD      HL,1A00H
        ADD     HL,DE
        LD      A,C
        AND     03H
        CP      00H
        LD      B,01H
        JP      Z,L1831
        CP      01H
        LD      B,02H
        JP      Z,L1831
        CP      02H
        LD      B,10H
        JP      Z,L1831
        LD      B,04H
L1831:  LD      A,(1956H)
        RRA     
        LD      A,B
        JP      C,L183E
        CPL     
        AND     (HL)
        JP      L183F
	
L183E:  OR      (HL)
L183F:  LD      (HL),A
        LD      HL,0E800H
        ADD     HL,DE
        LD      (HL),A
L1845:  POP     HL
        RET     

	ORG	1847h
Line:
        CALL    L0FB9
        LD      (1952H),A
        RST     SyntaxCheck
        DB	2ch
        CALL    L0FB9
        LD      (1953H),A
        PUSH    HL
        LD      HL,0100H
        LD      (194EH),HL
        LD      HL,0001H
        LD      (1950H),HL
        LD      HL,(1954H)
        LD      A,3FH
        SUB     H
        LD      H,A
        LD      A,(1952H)
        SUB     L
        LD      E,A
        OR      A
        JP      P,L187B
        CPL     
        ADD     A,01H
        LD      E,A
        LD      A,0FFH
        LD      (1950H),A
L187B:  LD      A,(1953H)
        SUB     H
        LD      D,A
        OR      A
        JP      P,L188D
        CPL     
        ADD     A,01H
        LD      D,A
        LD      A,0FFH
        LD      (194FH),A
L188D:  LD      A,E
        CP      D
        JP      P,L18A8
        LD      B,E
        LD      E,D
        LD      D,B
        LD      A,(1950H)
        LD      (194EH),A
        LD      A,(194FH)
        LD      (1951H),A
        XOR     A
        LD      (1950H),A
        LD      (194FH),A
L18A8:  LD      A,E
        RRA     
        LD      C,A
        LD      B,01H
L18AD:  LD      A,E
        CP      B
        JP      M,L1845
        LD      HL,(1954H)
        LD      A,3FH
        SUB     H
        LD      H,A
        LD      A,(1950H)
        ADD     A,L
        LD      (1954H),A
        LD      A,(1951H)
        ADD     A,H
        LD      (1955H),A
        LD      A,D
        ADD     A,C
        LD      C,A
        INC     B
        LD      A,E
        CP      C
        JP      P,L18E4
        LD      A,C
        SUB     E
        LD      C,A
        LD      HL,(1954H)
        LD      A,(194EH)
        ADD     A,L
        LD      (1954H),A
        LD      A,(194FH)
        ADD     A,H
        LD      (1955H),A
L18E4:  PUSH    BC
        PUSH    DE
        CALL    L17DD
        POP     DE
        POP     BC
        JP      L18AD

	ORG	18EEh
Msave:
        PUSH    HL
        LD      L,00H
        XOR     A
L18F2:  CALL    L0FEE
        DEC     L
        JP      NZ,L18F2
        POP     HL
        PUSH    HL
        LD      A,0E6H
        CALL    L0FEE
        LD      A,0D3H
        JP      L0FFD

	ORG	1905H
Mload:
        LD      (FACCUM),A
        CALL    L039E
        LD      B,03H
        LD      A,0FFH
        CALL    L0FE1
        CP      0D3H
        JP      Z,L1923
L1917:  LD      B,03H
L1919:  LD      A,08H
        CALL    L0FE1
        CP      0D3H
        JP      NZ,L1917
L1923:  DEC     B
        JP      NZ,L1919
        LD      HL,FACCUM
        LD      A,08H
        CALL    L0FE1
        CP      (HL)
        JP      NZ,L1917
        LD      HL,(PROGRAM_BASE)
L1936:  LD      B,03H
L1938:  LD      A,08H
        CALL    L0FE1
        LD      (HL),A
        CALL    L02BB
        LD      A,(HL)
        OR      A
        INC     HL
        JP      NZ,L1936
        DEC     B
        JP      NZ,L1938
        JP      L1051
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        db	0ch
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
	ORG	19c0h
	DB 72h, 61h, 7Ah, 72h, 61h, 62h, 6Fh, 74h,  41h, 4Eh, 4Fh, 20h, 44h, 4Ch, 71h, 20h	; "РАЗРАБОТANO DLЯ "
	DB 76h, 75h, 72h, 6Eh, 61h, 6Ch, 61h, 20h,  72h, 61h, 64h, 69h, 6Fh, 20h, 60h, 6Fh	; "ЖУРНАЛА РАДИО МО"
	DB 73h, 6Bh, 77h, 61h, 20h, 31h, 39h, 38h,  34h, 20h, 67h, 6Fh, 64h, 22h		; "СКВА 1984 ГОД""
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     

