; Disassembly of the file "C:\yuri\m80\Basic80.bin"
; 
; on Saturday, 24 of October 2020 at 03:54 PM
; Это дизассемблер бейсика "МИКРО-80". Имена меток взяты с дизассемблера Altair BASIC 3.2 (4K)
; По ходу разбора встречаются мысли и хотелки
;
; Общие хотелки:
; !?Добавить OPTION NOLET для управления наличием/отсутствием LET
; !?Добавить OPTION NOEND для управления наличием/отсутствием END
; !!Добавить поддержку каналов и потоков, как в Sinclair Basic, не забывая совместимость с ECMA стандартом
; !!Добавить поддержку дисковых операций через CP/M (с учетом, что под Микро-80 она существует) (ЗЫ: Базироваться на CP/M Бейсике не хочу)
; !!Отвязаться от RST и пересобрать с адреса 100h. Вначале добавить CP/M адаптер. При наличии поддержки дисковых фунок - адаптер не цепляем.
; !!Добавить OPTION BASE для управления индеском массива (Совместимость ANSI)
; !!Автонастройка памяти (сейчас жестко задано в коде)
; !!GO TO=GOTO, GO SUB=GOSUB
; ??ГОСТ расширение основных средств уровень 1 и 2 не могут быть реализованы из-за усеченного знакогенератора. Нет строчных букв.
; !!Развернутые сообщения об ошибках
; !!Отвязать по максимуму от работы в ОЗУ (версия для ROM-диска?)
;
; БЕЙСИК для МИКРО-80 - Общее устройство
;
; Как распределяется память
;
; +-------------------------------+ FFFFH
; !       ПЗУ  МОНИТОРа  (2К)     !
; +-------------------------------+ F800H
; !     Рабочие  ячейки  МОНИТОРа !
; +-------------------------------+ F750H
; !        Не  использована       !
; +-------------------------------+ F000H
; !          ОЗУ  экрана          !
; +-------------------------------+ E800H
; !         ОЗУ  курсора          !
; +-------------------------------+ E000H
; !        Не  использована       !
; +-------------------------------+ (MEM_TOP)
; !         Стек  Бейсика         !
; +-------------------------------+ (STACK_TOP)
; !            Массивы            !
; +-------------------------------+ (VAR_ARRAY_BASE)
; !           Переменные          !
; +-------------------------------+ (VAR_BASE)
; ! Текст  программы  на  Бейсике !
; +-------------------------------+ 2200H (PROGRAM_BASE)
; !         Буфер  экрана         !
; +-------------------------------+ 1A00H
; !      Область  подпрограмм     !
; !         пользователя          !
; +-------------------------------+ 1960H
; !    Интерпретатор  Бейсика     !
; +-------------------------------+ 0000H
;
; Lets consider the blocks of memory that follow Basic's own code in turn :
;
; The minimum amount of stack space is 18 bytes - at initialisation, after the
; user has stated the options they want, the amount of space is reported as 
; "X BYTES FREE", where X is 4096 minus (amount needed for Basic, plus 18 bytes
; for the stack). With all optional inline functions selected - SIN, RND, and SQR
; - X works out to 727 bytes. With no optional inline functions selected, the 
; amount increases to 973 bytes.
;
; Код программы
;
; На рис. показан формат строки программы на Бейсике в том виде, в каком она хранится в памяти микро-ЭВМ. 
; В начале каждой строки два байта отведены для хранения указателя адреса начала следующей строки программы,
; следующие два байта хранят номер строки, а заканчивается она байтом, заполненным одними нулями. Таким образом,
; текст программы хранится в памяти в виде специальной структуры данных, называемой в литературе "односвязным списком".
;
; Для большей эффективности по скорости и использованию памяти, программа храниться в токенизированном виде.
; Токенизация заключается в простой замене ключевых слов их идентификаторами. Идентификатора занимают один байта
; (более поздние версии используют 1- и 2-байтовые идентификаторы). Идентификатор определяется установленным
; старшим битом, т.е. коды индентификаторов находятся в диапазоне 0x80 - 0xFF.
;
; Например, строка:
;
; FOR I=1 TO 10
;
; В токенизированном виде выглядит как :
;
; 81 " I=1" 95 " 10"
;
; Здесь 081H - идентификатор для FOR, далее следует строка " I=1", после которой - идентификатор 095H для TO, и оканчивается
; строкой " 10". Всего 9 bytes вместо 13 байт для нетокенизированной строки.
;
; This particular example line of input is meaningless unless it is part of a larger program. As you should know already,
; each line of a program is prefixed with a line number. These line numbers get stored as 16-bit integers preceding the
; tokenised line content. Additionally, each line is stored with a pointer to the following line. Let's consider the 
; example input again, this time as a part of a larger program :
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

; Заканчивая обработку очередной строки программы, интерпретатор последовательно просматривает указатели списка до тех пор, пока не будет найдена строка с требуемым номером. Конец списка помечается двумя "нулевыми" байтами. Вы таким же образом можете вручную (с помощью директив Монитора) определить, где заканчивается программа, просматривая указатель списка до тех пор, пока не обнаружите три смежных байта, заполненных нулями. Во многих практических случаях, воспользовавшись рассмотренными рекомендациями, можно восстановить программу, в которой в результате сбоя была нарушена целостность списка. После восстановления структуры списка необходимо изменить значения, хранящиеся в ячейках памяти 0245Н и 0246Н. В этих ячейках хранятся значения соответственно младшего и старшего байта конечного адреса программы. Этот адрес на двойку превосходит адрес первого байта маркера конца списка.
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
; Массивы
; -------
;
; Массивы хранятся в отдельной области памяти, сразу после области переменных. Начала области массивов определяется переменной
; VAR_ARRAY_BASE. Массивы определяются ключевым словом DIM, and this version of Basic has the curious property where declaring
; an array of n elements results in n+1 elements being allocated, addressable with subscript values from 0 to n inclusive.
; Thus the following is quite legal :
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

; Конфигурация
MEM_TOP	EQU	03FFFH	; Верхний адрес доступной памяти
ANSI	EQU	0	; Включить поддержку совместимости с ANSI Minimal Basic
GOST	EQU	0	; Включить поддержку совместимости с ГОСТ 27787-88

	IF	ANSI
OPTION	EQU	1	; Поддержка команды OPTION
LET	EQU	1	; Поддержка команды LET
RANDOMIZE EQU	1	; Поддержка команды RANDOMIZE
END	EQU	1	; Поддержка команды END
	ELSE
	IF	GOST
OPTION	EQU	1	; Поддержка команды OPTION
LET	EQU	1	; Поддержка команды LET
RANDOMIZE EQU	1	; Поддержка команды RANDOMIZE
END	EQU	1	; Поддержка команды END
	ELSE
OPTION	EQU	0	; Поддержка команды OPTION
LET	EQU	0	; Поддержка команды LET
RANDOMIZE EQU	0	; Поддержка команды RANDOMIZE
END	EQU	0	; Поддержка команды END
	ENDIF
	ENDIF
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
; и обычно используются для часто вызываемых функций, что эконоит по 2 байта на каждом вызове.
; Всего Бейсик использует 7 рестартов.

; Начало (RST 0)

; Запуск интерпретатора осуществляется с адреса 0. Проводится инициализация стека и
; переход на код инициализации.


Start:
	LD	SP, MEM_TOP
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

SyntaxCheck:
	LD	A,(HL)
	EX	(SP),HL
	CP	(HL)
	INC	HL
	EX	(SP),HL
	JP	NZ,SyntaxError

;NextChar (RST 2)
;Return next character of input from the buffer at HL, skipping over space characters. 
;The Carry flag is set if the returned character is not alphanumeric,
; also the zero flag is set if a null character has been reached.

NextChar:
	INC	HL
	LD	A,(HL)
	CP	3AH
	RET	NC
	JP	NextChar_tail

;OutChar (RST 3)
;Prints a character to the terminal.

OutChar:
	PUSH	AF
	LD	A,(ControlChar)
	OR	A
	JP	OutChar_tail

;CompareHLDE (RST 4)
;Compares HL and DE with same logical results (C and Z flags) as for standard eight-bit compares.

CompareHLDE:
	LD	A,H
	SUB	D
	RET	NZ
	LD	A,L
	SUB	E
	RET
;
;TERMINAL_X and TERMINAL_Y
;Variables controlling the current X and Y positions of terminal output

TERMINAL_Y:	DB		01
TERMINAL_X:	DB		00
;
;FTestSign (RST 5)
;Tests the state of FACCUM. This part returns with A=0 and zero set if FACCUM==0, the tail of the function sets the sign flag and A accordingly (0xFF is negative, 0x01 if positive) before returning.

FTestSign:
	LD	A,(FACCUM+3)
	OR	A
	JP	NZ,FTestSign_tail
	RET  
;
;PushNextWord (RST 6)
;Effectively PUSH (HL). First we write the return address to the JMP instruction at the end of the function; then we read the word at (HL) into BC and push it onto the stack; lastly jumping to the return address.
;
PushNextWord:
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
	JP	04F9H		; Это самомодифицирующийся код


; токены и прочие данные
; 1.2 Keywords
;
; There are three groups of keywords :
;
; General keywords. These typically start a statement; examples are LET, PRINT, GOTO and so on.
; Supplementary keywords. Used in statements but not as part of an expression, eg TO, STEP, TAB
; Inline keywords. Only used in expressions, eg, SIN, RND, INT.
; 
;
; KW_INLINE_FNS
; A table of function pointers for the inline keywords.
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

; KW_ARITH_OP_FNS
;
; A table of function pointers for the arithmetic operator functions. 
; Four entries of three bytes each; the first entry byte is for operator 
; precedence and the second and third bytes are function pointers.

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

 
; KEYWORDS
;
; Строковые константы для всех ключевых слов, включая арифметические операторы. Последний символ определяется установкой в 1 старшего разряда.
; Конец таблицы отмечается нулевым байтом.

; Основные ключевые слова

	ORG	088h
; LET и END выкинули зачем-то... И этим поломали совместимость... В отчечественных бейсиках так много где произошло...

KEYWORDS:
Q	SET	80h
TK_CLS	EQU	Q
	DB	"CL", 'S'+80h	;	80
Q	SET	Q+1
TK_FOR	EQU	Q
	DB	"FO", 'R'+80h	;	81
Q	SET	Q+1
TK_NEXT	EQU	Q
	DB	"NEX", 'T'+80h	;	82
Q	SET	Q+1
TK_DATA	EQU	Q
	DB	"DAT", 'A'+80h	;	83
Q	SET	Q+1
TK_INPUT	EQU	Q
	DB 	"INPU", 'T'+80h	;	84
Q	SET	Q+1
TK_DIM	EQU	Q
	DB 	"DI", 'M'+80h	;	85
Q	SET	Q+1
TK_READ	EQU	Q
	DB 	"REA", 'D'+80h	;	86
Q	SET	Q+1
TK_CUR	EQU	Q
	DB 	"CU",	'R'+80h	;	87
Q	SET	Q+1
TK_GOTO	EQU	Q
	DB 	"GOT", 'O'+80h	;	88
Q	SET	Q+1
TK_RUN	EQU	Q
	DB 	"RU", 'N'+80h	;	89
Q	SET	Q+1
TK_IF	EQU	Q
	DB 	"I", 'F'+80h	;	8A
Q	SET	Q+1
TK_RESTORE	EQU	Q
	DB 	"RESTOR", 'E'+80h	;	8B
Q	SET	Q+1
TK_GOSUB	EQU	Q
	DB 	"GOSU", 'B'+80h	;	8C
Q	SET	Q+1
TK_RETURN	EQU	Q
	DB 	"RETUR", 'N'+80h;	8D
Q	SET	Q+1
TK_REM	EQU	Q
	DB 	"RE", 'M'+80h	;	8E
Q	SET	Q+1
TK_STOP	EQU	Q
	DB 	"STO", 'P'+80h	;	8F
Q	SET	Q+1
TK_OUT	EQU	Q
	DB	"OU", 'T'+80h	;	90
Q	SET	Q+1
TK_ON	EQU	Q
	DB	"O", 'N'+80h	;	91
Q	SET	Q+1
TK_PLOT	EQU	Q
	DB	"PLO", 'T'+80h	;	92
Q	SET	Q+1
TK_LINE	EQU	Q
	DB	"LIN", 'E'+80h	;	93
Q	SET	Q+1
TK_POKE	EQU	Q
	DB	"POK", 'E'+80h	;	94
Q	SET	Q+1
TK_PRINT	EQU	Q
	DB 	"PRIN", 'T'+80h	;	95
Q	SET	Q+1
TK_DEF	EQU	Q
	DB	"DE", 'F'+80h	;	96
Q	SET	Q+1
TK_CONT	EQU	Q
	DB	"CON", 'T'+80h	;	97
Q	SET	Q+1
TK_LIST	EQU	Q
	DB 	"LIS", 'T'+80h	;	98
Q	SET	Q+1
TK_CLEAR	EQU	Q
	DB 	"CLEA", 'R'+80h	;	99
Q	SET	Q+1
TK_MLOAD	EQU	Q
	DB	"MLOA", 'D'+80h	;	9a
Q	SET	Q+1
TK_MSAVE	EQU	Q
	DB	"MSAV", 'E'+80h	;	9b
Q	SET	Q+1
TK_NEW	EQU	Q
	DB 	"NE" , 'W'+80h	;	9c
	IF	OPTION
Q	SET	Q+1
TK_OPTION	EQU	Q
	DB	"OPTIO", 'N'+80h
	ENDIF
	IF	LET
Q	SET	Q+1
TK_LET	EQU	Q
	DB	"LE", 'T'+80h
	ENDIF
	IF	RANDOMIZE
Q	SET	Q+1
TK_RANDOMIZE	EQU	Q
	DB	"RANDOMIZE", 'E'+80h
	ENDIF
	IF	END
Q	SET	Q+1
TK_END	EQU	Q
	DB	"EN", 'D'+80h
	ENDIF
;Supplementary keywords
Q	SET	Q+1
TKCOUNT	EQU	Q-80H
TK_TAB	EQU	Q
	DB 	"TAB", '('+80h	;	9d
Q	SET	Q+1
TK_TO	EQU	Q
	DB 	"T", 'O'+80h	;	9e
Q	SET	Q+1
TK_SPC	EQU	Q
	DB	"SPC", '('+80h	;	9f
Q	SET	Q+1
TK_FN	EQU	Q
	DB	"F", 'N'+80h	;	a0
Q	SET	Q+1
TK_THEN	EQU	Q
	DB 	"THE", 'N'+80h	;	a1
Q	SET	Q+1
TK_NOT	EQU	Q
	DB	"NO", 'T'+80h	;	a2
Q	SET	Q+1
TK_STEP	EQU	Q
	DB 	"STE", 'P'+80h	;	a3
;Arithmetic and logical operators
Q	SET	Q+1
TK_PLUS	EQU	Q
	DB 	"+"+80h		;	a4
Q	SET	Q+1
TK_MINUS	EQU	Q
	DB 	"-"+80h		;	a5
Q	SET	Q+1
TK_MUL	EQU	Q
	DB	"*"+80h		;	a6
Q	SET	Q+1
TK_DIV	EQU	Q
	DB 	"/"+80h		;	a7
Q	SET	Q+1
TK_POWER	EQU	Q
	DB	'^'+80h		;	a8
Q	SET	Q+1
TK_AND	EQU	Q
	DB	"AN", 'D'+80h	;	a9
Q	SET	Q+1
TK_OR	EQU	Q
	DB	"O", 'R'+80h	;	aa
Q	SET	Q+1
TK_GT	EQU	Q
	DB 	">"+80h		;	ab
Q	SET	Q+1
TK_EQ	EQU	Q
	DB	"="+80h		;	ac
Q	SET	Q+1
TK_LT	EQU	Q
	DB 	"<"+80h		;	ad
;Inline keywords
Q	SET	Q+1
TK_SGN	EQU	Q
	DB 	"SG", 'N'+80h	;	ae
Q	SET	Q+1
TK_INT	EQU	Q
	DB 	"IN", 'T'+80h	;	af
Q	SET	Q+1
TK_ABS	EQU	Q
	DB 	"AB", 'S'+80h	;	b0
Q	SET	Q+1
TK_USR	EQU	Q
	DB 	"US", 'R'+80h	;	b1
Q	SET	Q+1
TK_FRE	EQU	Q
	DB	"FR", 'E'+80h	;	b2
Q	SET	Q+1
TK_INP	EQU	Q
	DB	"IN", 'P'+80h	;	b3
Q	SET	Q+1
TK_POS	EQU	Q
	DB	"PO", 'S'+80h	;	b4
Q	SET	Q+1
TK_SQR	EQU	Q
	DB 	"SQ", 'R'+80h	;	b5
Q	SET	Q+1
TK_RND	EQU	Q
	DB 	"RN", 'D'+80h	;	b6
Q	SET	Q+1
TK_LOG	EQU	Q
	DB	"LO", 'G'+80h	;	b7
Q	SET	Q+1
TK_EXP	EQU	Q
	DB	"EX", 'P'+80h	;	b8
Q	SET	Q+1
TK_COS	EQU	Q
	DB	"CO", 'S'+80h	;	b9
Q	SET	Q+1
TK_SIN	EQU	Q
	DB 	"SI", 'N'+80h	;	ba
Q	SET	Q+1
TK_TAN	EQU	Q
	DB	"TA", 'N'+80h	;	bb
Q	SET	Q+1
TK_ATN	EQU	Q
	DB	"AT", 'N'+80h	;	bc
Q	SET	Q+1
TK_PEEK	EQU	Q
	DB	"PEE", 'K'+80h	;	bd
Q	SET	Q+1
TK_LEN	EQU	Q
	DB	"LE", 'N'+80h	;	be
Q	SET	Q+1
TK_STRS	EQU	Q
	DB	"STR", '$'+80h	;	bf
Q	SET	Q+1
TK_VAL	EQU	Q
	DB	"VA", 'L'+80h	;	c0
Q	SET	Q+1
TK_ASC	EQU	Q
	DB	"AS", 'C'+80h	;	c1
Q	SET	Q+1
TK_CHRS	EQU	Q
	DB	"CHR", '$'+80h	;	c2
Q	SET	Q+1
TK_LEFTS	EQU	Q
	DB	"LEFT", '$'+80h	;	c3
Q	SET	Q+1
TK_RIGHTS	EQU	Q
	DB	"RIGHT", '$'+80h	;c4
Q	SET	Q+1
TK_MIDS	EQU	Q
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
	IF	OPTION
	DW	Option
	ENDIF
	IF	LET
	DW	Let
	ENDIF
	IF	RANDOMIZE
	DW	Randomize
	ENDIF
	IF	END
	DW	End
	ENDIF

;1.3 Error Codes & Globals
;A table of two-character error codes for the 18 errors.

;Ошибка 01. В программе встретился оператор NEXT, для которого не был выполнен соответствующий оператор FOR.
;Ошибка 02. Неверный синтаксис.
;Ошибка 03. В программе встретился оператор RETURN без предварительного выполнения оператора GOSUB.
;Ошибка 04. При выполнении программы не хватает данных для оператора READ. т.е. данных, описанных операторами DATA меньше, чем переменных в операторах READ.
;Ошибка 05. Аргумент функции не соответствует области определения данной функции. Например, отрицательный или нулевой аргумент функции LOG(X), отрицательный аргумент у функции SQR(X) и т. д.
;Ошибка 06. Переполнение при выполнении арифметических операций Результат любой операции не может быть больше +1,7-1035 или меньше -1,7-1035.
;Ошибка 07. Недостаточен объем памяти. Возможные причины:
;	велик текст программы:
;	слишком длинны массивы данных:
;	вложенность подпрограмм и циклов больше нормы;
;	слишком много переменных.
;Ошибка 08. Нет строки с данным номером. Возникает при выполнении операторов перехода.
;Ошибка 09. Индекс не соответствует размерности массива.
;Ошибка 10. Повторное выполнение операторов DIM или DEF, описывающих массив или функцию, которые уже были описаны ранее.
;Ошибка 11. Деление на ноль.
;Ошибка 12. Попытка выполнить операторы INPUT или DEP в непосредственном режиме.
;Ошибка 13. Несоответствие типов данных. Возникает при попытке символьной переменной присвоить числовое значение и наоборот.
;Ошибка 14. Переполнение буферной области памяти, отведенной для хранения символьных переменных. Для расширения объема буфера служит директива CLEAR.
;Ошибка 15. Длина символьной переменной превышает 255.
;Ошибка 16. Выражение, содержащее символьные переменные, слишком сложно для интерпретатора.
;Ошибка 17. Невозможность продолжения выполнения программы по директиве CONT.
;Ошибка 18. Обращение к функции, не описанной оператором DEF.


ERROR_CODES:
ERR_NF	EQU	$-ERROR_CODES
	DB	'0','1'+80h	; 00 NEXT without FOR
ERR_SN	EQU	$-ERROR_CODES
	DB	'0','2'+80h	; 02 Syntax Error
ERR_RG	EQU	$-ERROR_CODES
	DB	'0','3'+80h	; 04 RETURN without GOSUB
ERR_OD	EQU	$-ERROR_CODES
	DB	'0','4'+80h	; 06 Out of Data
ERR_FC	EQU	$-ERROR_CODES
	DB	'0','5'+80h	; 08 Illegal Function Call
ERR_OV	EQU	$-ERROR_CODES
	DB	'0','6'+80h	; 0A Overflow
ERR_OM	EQU	$-ERROR_CODES
	DB	'0','7'+80h	; 0C Out of memory
ERR_US	EQU	$-ERROR_CODES
	DB	'0','8'+80h	; 0E Undefined Subroutine
ERR_BS	EQU	$-ERROR_CODES
	DB	'0','9'+80h	; 10 Bad Subscript
ERR_DD	EQU	$-ERROR_CODES
	DB	'1','0'+80h	; 12 Duplicate Definition
ERR_DZ	EQU	$-ERROR_CODES
	DB	'1','1'+80h	; 14 Division by zero
ERR_ID	EQU	$-ERROR_CODES
	DB	'1','2'+80h	; 16 Invalid in Direct mode
ERR_TM	EQU	$-ERROR_CODES
	DB	'1','3'+80h	; 18 Type mismatch
ERR_SO	EQU	$-ERROR_CODES
	DB	'1','4'+80h	; 1AH Out of string space
ERR_LS	EQU	$-ERROR_CODES
	DB	'1','5'+80h	; 1CH String too long
ERR_ST	EQU	$-ERROR_CODES
	DB	'1','6'+80h	; 1EH String formula too complex
ERR_CN	EQU	$-ERROR_CODES
	DB	'1','7'+80h	; 20H Can't continue
ERR_UF	EQU	$-ERROR_CODES
	DB	'1','8'+80h	; 22H Undefined function

	org 01ceh

;LINE_BUFFER
;Buffer for a line of input or program, 73 bytes long.
;
;The line buffer is prefixed with this comma. It's here because the INPUT handler defers to the READ handler,
;which expects items of data (which the line buffer is treated as) to be prefixed with commas. Quite a neat trick!

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
ControlChar:
	DB		00		; Тип символа 00 - обычный символ FF - управляющий
            
        NOP     
        DB	01h
DATA_STM:
	DB	0			; Признак обработки TK_DATA
	DB	0FFH
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
NO_ARRAY:
	DB	00H				; Флаг, что переменная-массив недопустима (для TK_FOR, например)
INPUT_OR_READ:
	DB	00H
PROG_PTR_TEMP:
	DW	1722h				; Мусор, можно=0
PROG_PTR_TEMP2:
	DW	01d5h				; Мусор, можно=0
CURRENT_LINE:
	DW	0FFFFH		; Номер текущей исполняемой строки FFFF - никакая не исполняется
	DB	6eh, 0ah
	db	0,0
	ORG	0241H
STACK_TOP:
	DW	03fcdh				; Верхушка стека бейсика
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
FTEMP:	DB	0c2h
	db	20h
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

; Some useful functions.
; GetFlowPtr
; Sets HL to point to the appropriate flow struct on the stack. On entry, 
; if this was called by the NEXT keyword handler then DE is pointing to 
; the variable following the NEXT keyword.

	ORG 027ah


; The first four bytes on the stack are (or rather, should be) two return addresses.
; We're not interested in them, so the first thing to do is set HL to point to SP+4.

GetFlowPtr:		
	LD      HL,0004H
        ADD     HL,SP

;Get the keyword ID, the byte that precedes the flow struct. Then we increment HL
; so it points to (what should be) the flow struct, and return if the keyword ID is not 'FOR'.

GetFlowLoop:
	LD      A,(HL)
        INC     HL
        CP      TK_FOR
        RET     NZ

;Special treatment for FOR flow structs. Here we check that we've got the right one,
; ie the one required by the NEXT statement which called us. When we're called by NEXT,
; it sets DE to point to the variable in the NEXT statement. So here we get the first
; word of the FOR flow struct which is the address of the FOR variable, and compare
; it to the one we've been given in DE. If they match, then we've found the flow 
;struct wanted and we can safely return. If not then we jump 13 bytes up the 
;stack - 13 bytes is the size of the FOR flow struct - and loop back to try again.

        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        PUSH    HL
	LD      L,C
	LD      H,B
        LD      A,D
        OR      E

        EX      DE,HL
        JP      Z,NoVar			; NEXT без переменной (возравщвем первый попавшийся FOR)
        EX      DE,HL
        RST     CompareHLDE
NoVar:  LD      BC,000DH		; Размер структуры FOR
        POP     HL
        RET     Z

        ADD     HL,BC
        JP      GetFlowLoop
		
;		
; CopyMemoryUp
;
; Copies a block of memory from BC to HL. Copying is done backwards, 
; down to and including the point where BC==DE. It goes backwards 
; because this function is used to move blocks of memory forward by
; as little as a couple of bytes. If it copied forwards then the
; block of memory would overwrite itself.

		
CopyMemoryUp:
	CALL    CheckEnoughMem
;Exchange BC with HL, so HL now points to the source and BC points to destination.
CopyMemoryUpNoCheck:
	PUSH    BC
        EX      (SP),HL
        POP     BC
CopyMemLoop:
	RST     CompareHLDE
        LD      A,(HL)
        LD      (BC),A
        RET     Z

        DEC     BC
        DEC     HL
        JP      CopyMemLoop
		
; CheckEnoughVarSpace2
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
        LD      B,00H			;BC=C*4
        ADD     HL,BC
        ADD     HL,BC
        CALL    CheckEnoughMem
        POP     HL
        RET     

;CheckEnoughMem
;Checks that HL is more than 32 bytes away from the stack pointer. If HL is within 32 bytes
;of the stack pointer then this function falls into OutOfMemory.

CheckEnoughMem:
	PUSH    DE
        EX      DE,HL
        LD      HL,0FFDAH		; HL=-34 (extra 2 bytes for return address)
        ADD     HL,SP
        RST     CompareHLDE
        EX      DE,HL
        POP     DE
        RET     NC

;Three common errors.
;Notice use of LXI trick.

OutOfMemory:
	LD      E, ERR_OM
        JP      Error

L02CA:  LD      HL,(0233H)
        LD      (CURRENT_LINE),HL

SyntaxError:
	LD      E, ERR_SN
	DB		01				; LD BC,...
DivideByZero:
	LD      E, ERR_DZ
	DB		01				; LD BC,...
WithoutFOR:
	LD      E, ERR_NF

;Error
;Resets the stack, prints an error code (offset into error codes table is given in E), and stops program execution.
Error:
	CALL    ResetStack
        XOR     A
        LD      (ControlChar),A
        CALL    NewLine
        LD      HL,ERROR_CODES
        LD      D,A
        LD      A,'?'
        RST     OutChar
        ADD     HL,DE
        LD      A,(HL)
        RST     OutChar
        RST     NextChar
        RST     OutChar
        LD      HL, szError
PrintInLine:
	CALL    PrintString
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
	XOR	A
	LD	(ControlChar),A			; Включаем вывод на экран (не управляющий символ)
	LD	HL,0FFFFH			; Сбрасываем текущую выполняемую строку
	LD	(CURRENT_LINE),HL

	LD	HL,szOK				; Выводим приглашение
	CALL	PrintString

GetNonBlankLine:
	CALL	InputLine			; Считываем строку с клавиатуры
	RST	NextChar					; Считываем первый символ из буфера. Флаг переноса =1, если это цифра
	INC	A					; Проверяем на пустую строку. Инкремент/декремент не сбрасывает флаг переноса.
	DEC	A
	JP	Z, GetNonBlankLine	; Снова вводим строку, если пустая

	PUSH	AF					; Сохраняем флаг переноса
	CALL	LineNumberFromStr	; Получаем номер строки в DE
	PUSH	DE					; Запоминаем номер строки
	CALL	Tokenize			; Запускаем токенизатор. В C возвращается длина токенизированной строки, а в А = 0
	LD	B,A					; Теперь BC=длина строки
	POP	DE					; Восстанавливаем номер строки
	POP	AF					; Восстанавлливаем флаг переноса
	JP	NC, Exec			; Если у нас строка без номера, то сразу исполняем

;StoreProgramLine
;Here's where a program line has been typed, which we now need to store in program memory.

StoreProgramLine:
        PUSH    DE
        PUSH    BC
        RST     NextChar
        PUSH    AF
        CALL    FindProgramLine
        PUSH    BC
        JP      NC,InsertProgramLine

;Carry was set by the call to FindProgramLine, meaning that the line already exists.
; So we have to remove the old program line before inserting the new one in it's place.
; To remove the program line we simply move the remainder of the program 
;(ie every line that comes after it) down in memory.

RemoveProgramLine:
        EX      DE,HL
        LD      HL,(VAR_BASE)
RemoveProgramLineLoop:
	LD      A,(DE)
        LD      (BC),A
        INC     BC
        INC     DE
        RST     CompareHLDE
        JP      NC, RemoveProgramLineLoop
        LD      H,B
        LD      L,C
        INC     HL
        LD      (VAR_BASE),HL
;To insert the program line, firstly the program remainder (every line that comes
; after the one to be inserted) must be moved up in memory to make room.
InsertProgramLine:
	POP     DE
        POP     AF
        JP      Z,UpdateLinkedList
        LD      HL,(VAR_BASE)
        EX      (SP),HL
        POP     BC
        ADD     HL,BC
        PUSH    HL
        CALL    CopyMemoryUp
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
CopyFromBuffer:
        LD      DE,LINE_BUFFER		;Copy the line into the program
CopyFromBufferLoop:
	LD      A,(DE)
        LD      (HL),A
        INC     HL
        INC     DE
        OR      A
        JP      NZ,CopyFromBufferLoop

;Now the program line has been inserted/removed, all the pointers from each line to the next need to be updated.

UpdateLinkedList:
	CALL    ResetAll
        INC     HL
UpdateLinkedListLoop:
	LD      D,H
        LD      E,L
        LD      A,(HL)
        INC     HL
        OR      (HL)
        JP      Z,GetNonBlankLine
        INC     HL
        INC     HL
        INC     HL
        XOR     A
FindEndOfLine:
	CP      (HL)
        INC     HL
        JP      NZ,FindEndOfLine
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        EX      DE,HL
        JP      UpdateLinkedListLoop

;FindProgramLine
;Given a line number in DE, this function returns the address of that progam line in BC.
; If the line doesn't exist, then BC points to the next line's address, ie where the 
;line could be inserted. Carry flag is set if the line exists, otherwise carry reset.
		
FindProgramLine:
	LD      HL,(PROGRAM_BASE)
FindProgramLineInMem:
	LD      B,H
        LD      C,L
        LD      A,(HL)
        INC     HL
        OR      (HL)
        DEC     HL
        RET     Z

        PUSH    BC
        RST     PushNextWord
        RST     PushNextWord
        POP     HL
        RST     CompareHLDE
        POP     HL
        POP     BC
        CCF     
        RET     Z

        CCF     
        RET     NC

        JP      FindProgramLineInMem
		
;New
;Keyword NEW. Writes the null line number to the bottom of program storage (ie an empty program), updates pointer to variables storage,
; and falls into RUN which just happens to do the rest of the work NEW needs to do.

	ORG	039Dh
New:		
        RET     NZ

New2:
	LD      HL,(PROGRAM_BASE)
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (VAR_BASE),HL

;ResetAll
;Resets everything.
		
ResetAll:
;Set PROG_PTR_TEMP to just before the start of the program.
	LD      HL,(PROGRAM_BASE)
        DEC     HL
ClearAll:
	LD      (PROG_PTR_TEMP),HL
        LD      HL,(021BH)
        LD      (022FH),HL
;Reset the data pointer
        CALL    Restore
;Reset variable pointers
        LD      HL,(VAR_BASE)
        LD      (VAR_ARRAY_BASE),HL
        LD      (VAR_TOP),HL
;Get return address in BC and reset the stack pointer to it's top. 
ResetStack:
	POP     BC
        LD      HL,(STACK_TOP)
        LD      SP,HL

        LD      HL,021FH
        LD      (021DH),HL

        LD      HL,0000H
        PUSH    HL

        LD      (023FH),HL

        LD      HL,(PROG_PTR_TEMP)
        XOR     A
        LD      (NO_ARRAY),A
        PUSH    BC
        RET     

;InputLineWith'?'
;Gets a line of input at a '? ' prompt.

InputLineWithQ:
	LD      A, '?'
        RST     OutChar
        LD      A, ' '
        RST     OutChar
        JP      InputLine
		
;Tokenize
;Tokenises LINE_BUFFER, replacing keywords with their IDs. On exit, C holds the length of the tokenised line plus a few bytes to make it a 
;complete program line.

Tokenize:
	XOR     A
        LD      (DATA_STM),A
        LD      C,05H			; Initialise line length to 5
        LD      DE,LINE_BUFFER		; ie, output ptr is same as input ptr at start.
TokenizeNext:
;If char is a space, jump ahead to write it out.
	LD      A,(HL)
        CP      ' '
        JP      Z,WriteChar
;If char is a " (indicating a string literal) then freely copy up to the closing ". Obviously we don't want to tokenize string literals.
        LD      B,A
        CP      '"'
        JP      Z,FreeCopy
;If char is null then we've reached the end of input, and can exit this function.
        OR      A
        JP      Z,Exit
        LD      A,(DATA_STM)
        OR      A
        LD      B,A
        LD      A,(HL)
        JP      NZ,WriteChar
        CP      '?'
        LD      A, TK_PRINT		; Замена ? на PRINT
        JP      Z, WriteChar
        LD      A,(HL)
        CP      '0'
        JP      C,L041A
        CP      '<'
        JP      C,WriteChar
;Here's where we start to see if we've got a keyword. B здесь содержит 0 (см. код выше где OR A; LD B,A)
L041A:  PUSH    DE			; Preserve output ptr.
        LD      DE,KEYWORDS-1		; 
        PUSH    HL			; Preserve input ptr.
        DB	3Eh			; LD      A, ...
KwCompare:
	RST	NextChar		; Get next input char
        INC     DE
KwCompareDE:
	LD      A,(DE)			; Get keyword char to compare with.
        AND     7FH			; Ignore bit 7 of keyword char.
        JP      Z, NotAKeyword		; If keyword char==0, then end of keywords reached.
        CP      (HL)			; Keyword char matches input char?
        JP      NZ, NextKeyword		; If not, jump to get next keyword.
; OK, so input char == keyword char. Now we test bit 7 of the keyword char : if it's 0 then we haven't yet reached the end of the keyword and so have to loop back to continue comparing.
        LD      A,(DE)			
        OR      A
        JP      P, KwCompare
; Matched a keyword! First thing we do is remove input ptr from the stack, as since we're matched to a keyword we don't need to go back and try to match another keyword - HL is already the correct input ptr. Then we set A to the keyword ID which gets written out in the next block but one (notice we LXI over the next block).
        POP     AF			; Remove input ptr from stack. We don't need it.
        LD      A,B			; A=Keyword ID
        OR      80H			; Set bit 7 (indicates a keyword)
        DB	0F2H			; JP      P,...
; Here we have found that the input does not lead with a keyword, so we restore the input ptr and write out the literal character.
NotAKeyword:
	POP 	HL			; Restore input ptr
	LD 	A, (HL)			; and get input char
; Write character, and advance buffer pointers.
        POP     DE			; Restore output ptr
WriteChar:
	INC     HL			; Advance input ptr
        LD      (DE),A			; Store output char
        INC     DE			; Advance output ptr
        INC     C			; C++ (arf!).
; If we've just written the ID of keyword REM then we need to freecopy the rest of the line.
; Here we test for REM (8E) and jump back to the outer loop if it isn't. Note that if it is
; REM, then we set B to 0 so the freecopy won't stop prematurely.
        SUB     ':'
        JP      Z,L0447
        CP      TK_DATA-':'
        JP      NZ,L044A
L0447:  LD      (DATA_STM),A
L044A:  SUB     TK_REM-':'
        JP      NZ,TokenizeNext
        LD      B,A			; B=0

;Free copy loop. This loop copies from input to output without tokenizing, 
;as needs to be done for string literals and comment lines. The B register
;holds the terminating character - when this char is reached the free 
;copy is complete and it jumps back
	
FreeCopyLoop:
	LD      A,(HL)			; A=Input char
        OR      A			; If char is null then exit
        JP      Z,Exit			; 
        CP      B			; If input char is term char then 
        JP      Z,WriteChar		; we're done free copying.
FreeCopy:
	INC     HL
	LD      (DE),A
        INC     C
        INC     DE
        JP      FreeCopyLoop

; NextKeyword. Advances keyword ptr in DE to point to the next keyword in the table, then jumps back to KwCompare to see if it matches. Note we also increment the keyword ID.
	
NextKeyword:
	POP     HL			; Restore input ptr
        PUSH    HL
        INC     B			; Keyword ID ++
        EX      DE,HL			; HL=keyword table ptr
NextKwLoop:
	OR      (HL)			; Loop until
        INC     HL			; bit 7 of previous
        JP      P,NextKwLoop		; keyword char is set.
        EX      DE,HL			; DE=keyword ptr, HL=input ptr
        JP      KwCompareDE
	
Exit:	LD      HL,LINE_BUFFER-1
        LD      (DE),A
        INC     DE
        LD      (DE),A
        INC     DE
        LD      (DE),A
        RET     

;InputLine
;Gets a line of input into LINE_BUFFER.

Backspace:
	DEC     B			; Char count--;
        DEC     HL			; Input ptr--;
        RST     OutChar			; Print backspace char.
        JP      NZ,InputNext		; 
ResetInput:
	RST     OutChar
        CALL    NewLine
InputLine:
	LD      HL,LINE_BUFFER
        LD      B,01H
;Get a character and jump out of here if user has pressed 'Enter'. 
InputNext:
	CALL    InputChar
;Deal with backspace.
        CP      08H
        JP      Z,Backspace
        CP      0DH
        JP      Z,TerminateInput
;Deal with line-abort..
        CP      18H
        JP      Z,ResetInput
;If user has not given a printable character, then loop back until they do.
        CP      7FH
        JP      NC,InputNext
        CP      01H
        JP      C,InputNext
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
;A normal character has been pressed. Here we store it in LINE_BUFFER, only we don't if the terminal width has been exceeded. If the terminal width is exceeded then we ring the bell (ie print ASCII code 7) and ignore the char. Finally we loop back for the next input character.
        LD      C,A
        LD      A,B
        CP      72			; Длина LINE_BUFFER
        LD      A,07H
        JP      NC,IgnoreChar
        LD      A,C			; Write char to LINE_BUFFER.
        LD      (HL),C
        INC     HL
        INC     B
IgnoreChar:
	RST     OutChar
        JP      InputNext


OutChar_tail:
	JP      NZ,L0DC4
        POP     AF
        PUSH    AF
        CP      ' '
        JP      C,L04CD
        LD      A,(TERMINAL_X)
;;

;1.6 Terminal I/O
;OutChar_tail
;Prints a character to the terminal. On entry, the char to be printed is on the stack and A holds TERMINAL_X. 
;If the current line is up to the maximum width then we print a new line and update the terminal position.
; Then we print the character - to do this we loop until the device is ready to receive a char and then write it out.

        CP      48H
        CALL    Z,NewLine
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

InputChar:
	CALL    0F803h
        CP      1FH
        JP      Z,0F800h
        NOP     
        AND     7FH
        CP      0FH
        RET     NZ

        LD      A,(ControlChar)
        CPL     
        LD      (ControlChar),A
        RET     

;1.7 LIST Handler
;List
;Lists the program. As the stored program is in tokenised form 
;(ie keywords are represented with single byte numeric IDs) LIST
; is more complex than a simple memory dump. When it meets a 
;keyword ID it looks it up in the keywords table and prints it.

	ORG	04EEH
List:
        CALL    LineNumberFromStr
        RET     NZ

        POP     BC
        CALL    FindProgramLine
        PUSH    BC
ListNextLine:
	POP     HL
        RST     PushNextWord
	POP     BC
        LD      A,B
        OR      C
        JP      Z,Main
        CALL    TestBreakKey
        PUSH    BC
        CALL    NewLine
        RST     PushNextWord
        EX      (SP),HL
        CALL    PrintInt
        LD      A,' '
L050D:  POP     HL
ListChar:
	RST     OutChar
        LD      A,(HL)
        OR      A
        INC     HL
        JP      Z,ListNextLine
        JP      P,ListChar
        SUB     7FH
        LD      C,A
        PUSH    HL
        LD      DE, KEYWORDS
L051F:  PUSH    DE
ToNextKeyword:
	LD      A,(DE)
        INC     DE
        OR      A
        JP      P,ToNextKeyword
        DEC     C
        POP     HL
        JP      NZ,L051F
PrintKeyword:
	LD      A,(HL)
        OR      A
        JP      M,L050D
        RST     OutChar
        INC     HL
        JP      PrintKeyword

;1.8 FOR Handler
;For
;Although FOR indicates the beginning of a program loop, the handler only gets 
;called the once. Subsequent iterations of the loop return to the following
;statement or program line, not the FOR statement itself.

	ORG	0535H
For:		
        LD      A,64H
        LD      (NO_ARRAY),A
        CALL    Let
        EX      (SP),HL
        CALL    GetFlowPtr
        POP     DE
        JP      NZ,L0547
        ADD     HL,BC
        LD      SP,HL
L0547:  EX      DE,HL
        CALL    CheckEnoughVarSpace2
        DB	08H
        PUSH    HL
        CALL    FindNextStatement
        EX      (SP),HL
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        EX      (SP),HL
        CALL    L0969
        RST     SyntaxCheck
        DB	TK_TO
        CALL    L0966
        PUSH    HL
        CALL    FCopyToBCDE
        POP     HL
        PUSH    BC
        PUSH    DE
;Initialise the STEP value in BCDE to 1.
        LD      BC,8100H
        LD      D,C
        LD      E,D
        LD      A,(HL)
        CP      TK_STEP
        LD      A,01H
        JP      NZ,PushStepValue
        RST     NextChar
        CALL    L0966
        PUSH    HL
        CALL    FCopyToBCDE
        POP     HL
        RST     FTestSign
PushStepValue:
	PUSH    BC
        PUSH    DE
        PUSH    AF
        INC     SP
        
	PUSH    HL
	
	
        LD      HL,(PROG_PTR_TEMP)
        EX      (SP),HL
EndOfForHandler:
	LD      B,TK_FOR
        PUSH    BC
        INC     SP

;		
;1.9 Execution
;ExecNext
;Having exec'd one statement, this block moves on to the next statement 
;in the line or the next line if there are no more statements on the current line.
;

ExecNext:
	CALL    0F812h			;---------------
        NOP				; !! Этот блок можно заменить одним вызовом
        CALL    NZ,CheckBreak		;---------------
        LD      (PROG_PTR_TEMP),HL
        LD      A,(HL)
        CP      ':'
        JP      Z,Exec
        OR      A
        JP      NZ,SyntaxError
        INC     HL
        LD      A,(HL)
        INC     HL
        OR      (HL)
        INC     HL
        JP      Z,EndOfProgram
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      (CURRENT_LINE),HL
        EX      DE,HL
		
;Exec
;Executes a statement of BASIC code pointed to by HL.

		
Exec:	RST     NextChar
        LD      DE,ExecNext
        PUSH    DE
ExecANotZero:
	RET     Z

ExecA:
	SUB     80H
        JP      C,Let
        CP      TKCOUNT
        JP      NC,SyntaxError
        RLCA    			;	BC = A*2
        LD      C,A
        LD      B,00H
        EX      DE,HL
        LD      HL,KW_GENERAL_FNS
        ADD     HL,BC
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        PUSH    BC
        EX      DE,HL
		
; ЭТо дублирующий код из RST NextChar
NextChar2:
	INC     HL
        LD      A,(HL)
        CP      ':'
        RET     NC


;1.10 More Utility Functions
;NextChar_tail

NextChar_tail:
	CP      ' '
        JP      Z,NextChar2
        CP      '0'
        CCF     
        INC     A
        DEC     A
        RET     

;Restore
;Resets the data pointer to just before the start of the program.

	ORG	05DBh
Restore:
	EX      DE,HL
        LD      HL,(PROGRAM_BASE)
        DEC     HL
L05E0:  LD      (DATA_PROG_PTR),HL
        EX      DE,HL
        RET     

;TestBreakKey
;Apparently the Altair had a 'break' key, to break program execution. 
;This little function tests to see if the terminal input device is ready,
; and returns if it isn't. If it is ready (ie user has pressed a key) 
;then it reads the char from the device, compares it to the code for
; the break key (0x03) and jumps to Stop. Since the first instruction 
;at Stop is RNZ, this will return at once if the user pressed some other key.

TestBreakKey:
	CALL    0F812h
        NOP     
        RET     Z

CheckBreak:
	CALL    InputChar
        CP      03H
	
	ORG	05efh
Stop:
        RET     NZ

        OR      0C0H
        LD      (PROG_PTR_TEMP),HL
L05F5:  POP     BC

EndOfProgram:
	PUSH    AF
        LD      HL,(CURRENT_LINE)
        LD      A,L
        AND     H
        INC     A
        JP      Z,L0609
        LD      (023DH),HL
        LD      HL,(PROG_PTR_TEMP)
        LD      (023FH),HL
L0609:  XOR     A
        LD      (ControlChar),A
        POP     AF
        LD      HL, szStop
        JP      NZ, PrintInLine
        JP      Main

	ORG	0617H
Cont:	
        RET     NZ

        LD      E,ERR_CN
        LD      HL,(023FH)
        LD      A,H
        OR      L
        JP      Z,Error
        EX      DE,HL
        LD      HL,(023DH)
        LD      (CURRENT_LINE),HL
        EX      DE,HL
        RET     


        CALL    L0FB9
        RET     NZ

        INC     A
        CP      48H
        JP      NC,FunctionCallError
        LD      (TERMINAL_Y),A
        RET     
;
;CharIsAlpha
;If character pointed to by HL is alphabetic, the carry flag is reset otherwise set.
;
CharIsAlpha:
	LD      A,(HL)
        CP      'A'
        RET     C

        CP      'Z'+1
        CCF
        RET


;GetSubscript
;Gets the subscript of an array variable encountered in an expression or a DIM declaration. The subscript is returned as a positive integer in CDE.

GetSubscript:
	RST     NextChar
L0642:  CALL    L0966
L0645:  RST     FTestSign
        JP      M,FunctionCallError
L0649:  LD      A,(FACCUM+3)
        CP      90H
        JP      C,FAsInteger
        LD      BC,9080H
        LD      DE,0000H
        CALL    FCompare
        LD      D,C
        RET     Z

FunctionCallError:
	LD      E,ERR_FC
        JP      Error
		
;1.11 Jumping to Program Lines
;LineNumberFromStr
;Gets a line number from a string pointer. The string pointer is passed in in HL,
; and the integer result is returned in DE. Leading spaces are skipped over, and 
;it returns on finding the first non-digit. The largest possible line number is 
;65529 - it syntax errors out if the value of the first four digits is more then 6552.

;One interesting feature of this function is that it returns with Z set if it
; found a valid number (or the string was empty), or NZ if the string
; didn't lead with a number.
		
LineNumberFromStr:
	DEC     HL
LineNumberFromStr2:
	LD      DE,0000H
NextLineNumChar:
	RST     NextChar
        RET     NC

        PUSH    HL
        PUSH    AF
        LD      HL,1998H
        RST     CompareHLDE
        JP      C,SyntaxError
        LD      H,D
        LD      L,E
        ADD     HL,DE
        ADD     HL,HL
        ADD     HL,DE
        ADD     HL,HL
        POP     AF
        SUB     '0'
        LD      E,A
        LD      D,00H
        ADD     HL,DE
        EX      DE,HL
        POP     HL
        JP      NextLineNumChar
	
	ORG	0682H
Clear:
        JP      Z,ClearAll
        CALL    L0642
        DEC     HL
        RST     NextChar
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
        RST     CompareHLDE
        JP      NC,OutOfMemory
        EX      DE,HL
        LD      (STACK_TOP),HL
        POP     HL
        JP      ClearAll
;;;		
	ORG	06ABH
Run:
        JP      Z,ResetAll
        CALL    ClearAll
        LD      BC,ExecNext
        JP      GosubBC
	
;Gosub
;Gosub sets up a flow struct on the stack and then falls into Goto. The flow struct is KWID_GOSUB, preceded by the line number of the gosub statement, in turn preceded by prog ptr to just after the gosub statement.
	
	ORG	06B7H
Gosub:
        CALL    CheckEnoughVarSpace2
        DB	03h
        POP     BC
        PUSH    HL
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        EX      (SP),HL
        LD      D,TK_GOSUB
        PUSH    DE
        INC     SP
;Push return address preserved in BC, and fall into GOTO.
GosubBC:  PUSH    BC

;Goto
;Sets program execution to continue from the line number argument.

;Get line number argument in DE and return NZ indicating syntax error if the argument was a non-number .
	ORG	06C7H
Goto:
	CALL    LineNumberFromStr
        CALL    Rem
        PUSH    HL
        LD      HL,(CURRENT_LINE)
        RST     CompareHLDE
        POP     HL
        INC     HL
        CALL    C,FindProgramLineInMem
        CALL    NC,FindProgramLine
        LD      H,B
        LD      L,C
        DEC     HL
        RET     C

        LD      E,ERR_US
        JP      Error
		
		
;		Return
;Returns program execution to the statement following the last GOSUB. Information about where to return to is kept on the stack in a flow struct (see notes).

	ORG	06e3h
Return:

;No arguments allowed.
        RET     NZ
        LD      D,0FFH
        CALL    GetFlowPtr
        LD      SP,HL
        CP      TK_GOSUB
        LD      E,ERR_RG
        JP      NZ,Error
        POP     HL
        LD      (CURRENT_LINE),HL
        LD      HL,ExecNext
        EX      (SP),HL
		
;Safe to fall into FindNextStatement, since we're already at the end of the line!...

 

;FindNextStatement
;Finds the end of the statement or the end of the program line.


;Rem is jumped to in two places - it is the REM handler, and also when an IF statement's condition evals to false and the rest of the line needs to be skipped. Luckily in both these cases, C just happens to be loaded with a byte that cannot occur in the program so the null byte marking the end of the line is found as expected.

Data:
FindNextStatement:
	DB	01H
	DB	':'		;LD      BC,..3AH
Rem:
	DB	0EH		;LD		C, 0
        NOP     
        LD      B,00H
ExcludeQuote:
	LD      A,C
        LD      C,B
        LD      B,A
FindNextStatementLoop:
	LD      A,(HL)
        OR      A
        RET     Z

        CP      B
        RET     Z

        INC     HL
        CP      '"'
        JP      Z,ExcludeQuote
        JP      FindNextStatementLoop

;1.12 Assigning Variables
;Let
;Assigns a value to a variable.

Let:	CALL    GetVar
        RST     SyntaxCheck
        DB	TK_EQ			; '='
        LD      A,(0219H)
        PUSH    AF
        PUSH    DE
        CALL    EvalExpression
        EX      (SP),HL
        LD      (PROG_PTR_TEMP),HL
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
        RST     PushNextWord
        POP     DE
        LD      HL,(STACK_TOP)
        RST     CompareHLDE
        POP     DE
        JP      NC,L0745
        LD      HL,(VAR_BASE)
        RST     CompareHLDE
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
        CALL    FCopyToMem
        POP     DE
        POP     HL
        RET     

; Обработчик ON x GOTO/ON x GOSUB

	ORG	075Ch
On:
        CALL    L0FB9
        LD      A,(HL)
        LD      B,A
        CP      TK_GOSUB
        JP      Z,OkToken
        RST     SyntaxCheck
        DB	TK_GOTO
        DEC     HL
OkToken:
	LD      C,E
OnLoop:
	DEC     C
        LD      A,B
        JP      Z,ExecA
        CALL    LineNumberFromStr2
        CP      ','
        RET     NZ

        JP      OnLoop

;1.13 IF Keyword Handler
;If
;Evaluates a condition. A condition has three mandatory parts : a left-hand side expression, a comparison operator, and a right-hand side expression. Examples are 'A=2', 'B<=4' and so on.

;The comparison operator is one or more of the three operators '>', '=', and '<'. Since these three operators can appear more than once, and in any order, the code does something rather clever to convert them to a single 'comparison operator value'. This value has bit 0 set if '>' is present, bit 1 for '=', and bit 2 for '<'. Thus the comparison operators '<=' and '=<' are both 6, likewise '>=' and '=>' are both 3, and '<>' is 5

;You can therefore get away with stupid operators such as '>>>>>' (value 1, the same as a single '>') and '>=<' (value 7), the latter being particularly dense as it causes the condition to always evaluate to true.

	ORG	0778h
If:
        CALL    EvalExpression
        LD      A,(HL)
        CP      TK_GOTO			; !!Добавить IF x GOSUB
        JP      Z, NoThen
        RST     SyntaxCheck
        DB	TK_THEN
        DEC     HL
NoThen:
	RST     FTestSign
        JP      Z,Rem

;Condition evaluated to True. Here we get the first character of the THEN statement,
; and if it's a digit then we jump to GOTO's handler as it's an implicit GOTO. 
;Otherwise we jump to near the top of Exec to run the THEN statement.
	
        RST     NextChar
        JP      C,Goto			; Если число, то это GOTO
        JP      ExecANotZero		; Если конец строки, то возврат, иначе исполняем команду
		
;1.14 Printing
;Print
;Prints something! It can be an empty line, a single expression/literal, 
;or multiple expressions/literals seperated by tabulation directives 
;(comma, semi-colon, or the TAB keyword).
		
        DEC     HL
PrintLoop:
	RST     NextChar

	ORG	0791H
Print:
        JP      Z,NewLine
L0794:  RET     Z

        CP      TK_TAB
        JP      Z,Tab
        CP      TK_SPC
        JP      Z,Tab
        PUSH    HL
        CP      ','
        JP      Z,L07F4
        CP      ';'
        JP      Z,ExitTab
        POP     BC
        CALL    EvalExpression
        DEC     HL
        PUSH    HL
        LD      A,(0219H)
        OR      A
        JP      NZ,L07D0
        CALL    FOut
        CALL    L0D4F
        LD      HL,(FACCUM)
        LD      A,(TERMINAL_X)
        ADD     A,(HL)
        CP      '@'
        CALL    NC,NewLine
        CALL    L0D96
        LD      A, ' '
        RST     OutChar
        XOR     A
L07D0:  CALL    NZ,L0D96
        POP     HL
        JP      PrintLoop
		
;TerminateInput
;HL points to just beyond the last byte of a line of user input. Here we write a null byte to terminate it,
; reset HL to point to the start of the input line buffer, then fall into NewLine.
		
TerminateInput:
	LD      (HL),00H
        LD      HL,LINE_BUFFER-1
		
;NewLine
;Prints carriage return + line feed, plus a series of nulls which was probably due to some peculiarity of the teletypes of the day.

NewLine:
	LD      A,0DH
        LD      (TERMINAL_X),A
        RST     OutChar
        LD      A,0AH
        RST     OutChar
L07E5:  LD      A,(TERMINAL_Y)
PrintNullLoop:
	DEC     A
        LD      (TERMINAL_X),A
        RET     Z

        PUSH    AF
        XOR     A
        RST     OutChar
        POP     AF
        JP      PrintNullLoop
		

;ToNextTabBreak
;Calculate how many spaces are needed to get us to the next tab-break then jump to PrintSpaces to do it.
		
L07F4:  LD      A,(TERMINAL_X)
        CP      30H
        CALL    NC,NewLine
        JP      NC,ExitTab
L07FF:  SUB     0EH
        JP      NC,L07FF
        CPL     
        JP      L081F
		
;Tab и Spc
;Tabulation. The TAB keyword takes an integer argument denoting the absolute column to print spaces up to.
		
Tab:
	PUSH    AF
        CALL    L0FB8
        RST     SyntaxCheck
        DB	')'
        DEC     HL
        POP     AF
        CP      TK_SPC
        PUSH    HL
        LD      A,E
        JP      Z,Spc
        LD      A,(TERMINAL_X)
        CPL     
        ADD     A,E
        JP      NC,ExitTab
PrintSpaces:
L081F:  INC     A

Spc:	
	LD      B,A
        LD      A, ' '
PrintSpaceLoop:
	RST     OutChar
        DEC     B
        JP      NZ,PrintSpaceLoop
ExitTab:
	POP     HL
        RST     NextChar
        JP      L0794

szRepeat:
	DB	3Fh, 70h, 6Fh, 77h, 74h, 6Fh, 72h, 69h, 74h, 65h, 20h, 77h, 77h, 6Fh, 64h, 0A0h, 0Dh, 0Ah, 00	; "?ПОВТОРИТЕ ВВОД "
		
L0840:  LD      A,(INPUT_OR_READ)
        OR      A
        JP      NZ,L02CA
        POP     BC
        LD      HL, szRepeat
        CALL    PrintString
        LD      HL,(PROG_PTR_TEMP)
        RET     

	ORG	0852h
Input:
        CP      22H
        LD      A,00H
        LD      (ControlChar),A
        JP      NZ,L0866
        CALL    L0D50
        RST     SyntaxCheck
        DB	';'
        PUSH    HL
        CALL    L0D96
        POP     HL
L0866:  PUSH    HL
        CALL    L0D02
        CALL    InputLineWithQ
        INC     HL
        LD      A,(HL)
        OR      A
        DEC     HL
        POP     BC
        JP      Z,L05F5
        PUSH    BC
        JP      ReadParse

	ORG	0879h
Read:
        PUSH    HL
        LD      HL,(DATA_PROG_PTR)
        DB	0f6h		;OR      0AFH
ReadParse:
	XOR	A
        LD      (INPUT_OR_READ),A
        EX      (SP),HL
        DB	01h		; LD      BC,...
ReadNext:
	RST	SyntaxCheck
	DB	','
        CALL    GetVar
        EX      (SP),HL
        PUSH    DE
        LD      A,(HL)
        CP	','
        JP      Z,GotDataItem
        LD      A,(INPUT_OR_READ)
        OR      A
        JP      NZ,ReadError
        LD      A, '?'
        RST     OutChar
        CALL    InputLineWithQ
GotDataItem:
	LD      A,(0219H)
        OR      A
        JP      Z,L08BE
        RST     NextChar
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
L08BE:  RST     NextChar
        CALL    FIn
        EX      (SP),HL
        CALL    FCopyToMem
        POP     HL
        DEC     HL
        RST     NextChar
        JP      Z,L08D1
        CP      2CH
        JP      NZ,L0840
L08D1:  EX      (SP),HL
        DEC     HL
        RST     NextChar
        JP      NZ,0884h
        POP     DE
        LD      A,(INPUT_OR_READ)
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

ReadError:
	CALL    FindNextStatement
        OR      A
        JP      NZ,L0914
        INC     HL
        RST     PushNextWord
        LD      A,C
        OR      B
        LD      E,ERR_OD
        JP      Z,Error
        POP     BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      (0233H),HL
        EX      DE,HL
L0914:  RST     NextChar
        CP      83H
        JP      NZ,ReadError
        JP      GotDataItem

;1.16 NEXT Handler
;Next
;The NEXT keyword is followed by the name of the FOR variable, so firstly we get the address of that variable into DE.

	ORG	091Dh
Next:
        LD      DE,0000H
L0920:  CALL    NZ,GetVar
        LD      (PROG_PTR_TEMP),HL
        CALL    GetFlowPtr
        JP      NZ,WithoutFOR
        LD      SP,HL
        PUSH    DE
        LD      A,(HL)
        INC     HL
        PUSH    AF
        PUSH    DE
        CALL    FLoadFromMem
        EX      (SP),HL
        PUSH    HL
        CALL    FAddFromMem
        POP     HL
        CALL    FCopyToMem
        POP     HL
        CALL    FLoadBCDEfromMem
        PUSH    HL
        CALL    FCompare
        POP     HL
        POP     BC
        SUB     B
        CALL    FLoadBCDEfromMem
        JP      Z,L0958
        EX      DE,HL
        LD      (CURRENT_LINE),HL
        LD      L,C
        LD      H,B
        JP      EndOfForHandler
	
L0958:  LD      SP,HL
        LD      HL,(PROG_PTR_TEMP)
        LD      A,(HL)
        CP      2CH
        JP      NZ,ExecNext
        RST     NextChar
        CALL    L0920
L0966:  CALL    EvalExpression
L0969:  OR      37H
L096B:  LD      A,(0219H)
        ADC     A,A
        RET     PE

        LD      E,ERR_TM
        JP      Error

;1.17 Expression Evaluation
;EvalExpression
;Evaluates an expression, returning with the result in FACCUM. An expression is a combination of terms and operators.

EvalExpression:
	DEC     HL
        LD      D,00H
L0978:  PUSH    DE
        CALL    CheckEnoughVarSpace2
	DB	01h
	CALL	EvalTerm
        LD      (PROG_PTR_TEMP2),HL
L0983:  LD      HL,(PROG_PTR_TEMP2)
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
        RST     NextChar
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
        CALL    FPush
        LD      E,B
        LD      D,C
        RST     PushNextWord
        LD      HL,(0231H)
        JP      L0978
	
EvalTerm:
	XOR     A
L09E6:  LD      (0219H),A
        RST     NextChar
        JP      C,FIn
        CALL    CharIsAlpha
        JP      NC,L0A2F
        CP      0A4H
        JP      Z,EvalTerm
        CP      2EH
        JP      Z,FIn
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
        DB	'('
	CALL	EvalExpression
        RST     SyntaxCheck
L0A1C:  DB	')'
        RET     

L0A1E:  LD      D,7DH
        CALL    L0978
        LD      HL,(PROG_PTR_TEMP2)
        PUSH    HL
        CALL    FNegate
        CALL    L0969
        POP     HL
        RET     

L0A2F:  CALL    GetVar
        PUSH    HL
        EX      DE,HL
        LD      (FACCUM),HL
        LD      A,(0219H)
        OR      A
        CALL    Z,FLoadFromMem
        POP     HL
        RET     

L0A40:  LD      B,00H
        RLCA    
        LD      C,A
        PUSH    BC
        RST     NextChar
        LD      A,C
        CP      29H
        JP      C,L0A65
        RST     SyntaxCheck
	DB	'('
	CALL	EvalExpression

        RST     SyntaxCheck
        DB	','
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
        CALL    FLoadFromBCDE
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
        JP      Z,FCompare
        XOR     A
        LD      (0219H),A
        PUSH    DE
        CALL    L0EC1
        POP     DE
        RST     PushNextWord
        RST     PushNextWord
        CALL    L0EC5
        CALL    FLoadBCDEfromMem
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

DimContd:
	DEC     HL
        RST     NextChar
        RET     Z

        RST     SyntaxCheck
        DB	','

	ORG	0B15H
Dim:
        LD      BC,DimContd
        PUSH    BC
        DB	0f6h	; OR      0AFH
GetVar:	XOR	A
        LD      (0218H),A
        LD      B,(HL)
L0B1F:  CALL    CharIsAlpha
        JP      C,SyntaxError
        XOR     A
        LD      C,A
        LD      (0219H),A
        RST     NextChar
        JP      C,L0B34
        CALL    CharIsAlpha
        JP      C,L0B3F
L0B34:  LD      C,A
L0B35:  RST     NextChar
        JP      C,L0B35
        CALL    CharIsAlpha
        JP      NC,L0B35
L0B3F:  SUB     24H
        JP      NZ,L0B4C
        INC     A
        LD      (0219H),A
        RRCA    
        ADD     A,C
        LD      C,A
        RST     NextChar
L0B4C:  LD      A,(NO_ARRAY)
        ADD     A,(HL)
        CP      28H
        JP      Z,L0B9E
        XOR     A
        LD      (NO_ARRAY),A
        PUSH    HL
        LD      HL,(VAR_ARRAY_BASE)
        EX      DE,HL
        LD      HL,(VAR_BASE)
L0B61:  RST     CompareHLDE
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
        CALL    CopyMemoryUp
        POP     HL
        LD      (VAR_TOP),HL
        LD      H,B
        LD      L,C
        LD      (VAR_ARRAY_BASE),HL
L0B8F:  DEC     HL
        LD      (HL),00H
        RST     CompareHLDE
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
        CALL    GetSubscript
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
        DB	')'
        LD      (PROG_PTR_TEMP2),HL
        POP     HL
        LD      (0218H),HL
        PUSH    DE
        LD      HL,(VAR_ARRAY_BASE)
        LD      A,19H
        EX      DE,HL
        LD      HL,(VAR_TOP)
        EX      DE,HL
        RST     CompareHLDE
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
        LD      E,ERR_DD
        JP      NZ,Error
        POP     AF
        CP      (HL)
        JP      Z,L0C52
L0BEE:  LD      E,ERR_BS
        JP      Error
	
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
        CALL    CheckEnoughMem
        LD      (VAR_TOP),HL
L0C34:  DEC     HL
        LD      (HL),00H
        RST     CompareHLDE
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
        RST     CompareHLDE
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
L0C74:  LD      HL,(PROG_PTR_TEMP2)
        DEC     HL
        RST     NextChar
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
        LD      HL,(STACK_TOP)
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
        LD      BC,FindNextStatement
        PUSH    BC
        PUSH    DE
        CALL    L0D02
        RST     SyntaxCheck
	DB	'('
	CALL	GetVar
        CALL    L0969
        RST     SyntaxCheck
        DB	')'
        RST     SyntaxCheck
        DB	TK_EQ
        LD      B,H
        LD      C,L
        EX      (SP),HL
        JP      L0CF9
	
L0CCD:  CALL    L0D10
        PUSH    DE
        CALL    L0A16
        CALL    L0969
        EX      (SP),HL
        RST     PushNextWord
        POP     DE
        RST     PushNextWord
        POP     HL
        RST     PushNextWord
        RST     PushNextWord
        DEC     HL
        DEC     HL
        DEC     HL
        DEC     HL
        PUSH    HL
        RST     CompareHLDE
        PUSH    DE
        LD      E,ERR_UF
        JP      Z,Error
        CALL    FCopyToMem
        POP     HL
        CALL    L0966
        DEC     HL
        RST     NextChar
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

        LD      E,ERR_ID
        JP      Error
L0D10:  RST     SyntaxCheck
        DB	TK_FN
        LD      A,80H
        LD      (NO_ARRAY),A
        OR      (HL)
        LD      B,A
        CALL    L0B1F
        JP      L0969
	
	ORG	0d1fh
Str:
        CALL    L0969
        CALL    FOut
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
        RST     PushNextWord
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
        CALL    Z,NextChar2
        EX      (SP),HL
        INC     HL
        EX      DE,HL
        LD      A,C
        CALL    L0D46
        RST     CompareHLDE
        CALL    NC,L0D2F
L0D75:  LD      DE,022BH
        LD      HL,(021DH)
        LD      (FACCUM),HL
        LD      A,01H
        LD      (0219H),A
        CALL    L131C
        RST     CompareHLDE
        LD      E,ERR_ST
        JP      Z,Error
        LD      (021DH),HL
        POP     HL
        LD      A,(HL)
        RET     

        INC     HL
PrintString:
	CALL    L0D4F
L0D96:  CALL    L0EC1
        CALL    FLoadBCDEfromMem
        INC     E
L0D9D:  DEC     E
        RET     Z

        LD      A,(BC)
        RST     OutChar
        CP      0DH
        CALL    Z,L07E5
        INC     BC
        JP      L0D9D
		
L0DAA:  OR      A
        LD      C,0F1H
        PUSH    AF
        LD      HL,(STACK_TOP)
        EX      DE,HL
        LD      HL,(022FH)
        CPL     
        LD      C,A
        LD      B,0FFH
        ADD     HL,BC
        INC     HL
        RST     CompareHLDE
        JP      C,L0DC6
        LD      (022FH),HL
        INC     HL
        EX      DE,HL
L0DC4:  POP     AF
        RET     

L0DC6:  POP     AF
        LD      E,ERR_SO
        JP      Z,Error
        CP      A
        PUSH    AF
        LD      BC,0DACH
        PUSH    BC
L0DD2:  LD      HL,(021BH)
L0DD5:  LD      (022FH),HL
        LD      HL,0000H
        PUSH    HL
        LD      HL,(STACK_TOP)
        PUSH    HL
        LD      HL,021FH
        EX      DE,HL
        LD      HL,(021DH)
        EX      DE,HL
        RST     CompareHLDE
        LD      BC,0DE3H
        JP      NZ,L0E2F
        LD      HL,(VAR_BASE)
L0DF2:  EX      DE,HL
        LD      HL,(VAR_ARRAY_BASE)
        EX      DE,HL
        RST     CompareHLDE
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
        RST     CompareHLDE
        JP      Z,L0E52
        CALL    FLoadBCDEfromMem
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
        RST     CompareHLDE
        JP      Z,L0E06
        LD      BC,0E23H
L0E2F:  PUSH    BC
        OR      80H
L0E32:  RST     PushNextWord
        RST     PushNextWord
        POP     DE
        POP     BC
        RET     P

        LD      A,C
        OR      A
        RET     Z

        LD      B,H
        LD      C,L
        LD      HL,(022FH)
        RST     CompareHLDE
        LD      H,B
        LD      L,C
        RET     C

        POP     HL
        EX      (SP),HL
        RST     CompareHLDE
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
        CALL    CopyMemoryUpNoCheck
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
        CALL    EvalTerm
        EX      (SP),HL
        CALL    096Ah
        LD      A,(HL)
        PUSH    HL
        LD      HL,(FACCUM)
        PUSH    HL
        ADD     A,(HL)
        LD      E,ERR_LS
        JP      C,Error
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
        RST     PushNextWord
        RST     PushNextWord
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
        RST     CompareHLDE
        EX      DE,HL
        RET     NZ

        LD      (021DH),HL
        PUSH    DE
        LD      D,B
        LD      E,C
        DEC     DE
        LD      C,(HL)
        LD      HL,(022FH)
        RST     CompareHLDE
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
        JP      Z,FunctionCallError
        INC     HL
        INC     HL
        RST     PushNextWord
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
        CP      ')'
        JP      Z,L0F60
        RST     SyntaxCheck
        DB	','
        CALL    L0FB9
L0F60:  RST     SyntaxCheck
        DB	')'
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
        RST     NextChar
        JP      Z,L0F96
        RST     SyntaxCheck
        DB	','
        CALL    L0FB9
L0F96:  POP     BC
L0F97:  IN      A,(00H)
        XOR     E
        AND     B
        JP      Z,L0F97
        RET     

L0F9F:  EX      DE,HL
        RST     SyntaxCheck
        DB	')'
L0FA2:  POP     BC
        POP     DE
        PUSH    BC
        LD      B,E
        INC     B
        DEC     B
        JP      Z,FunctionCallError
        RET     

L0FAC:  CALL    L0FB9
        LD      (0F98H),A
        LD      (0F84H),A
        RST     SyntaxCheck
        DB	','
        DB	06h	;LD      B,..
L0FB8:	RST	NextChar
L0FB9:  CALL    L0966
L0FBC:  CALL    L0645
        LD      A,D
        OR      A
        JP      NZ,FunctionCallError
        DEC     HL
        RST     NextChar
        LD      A,E
        RET     

	ORG	0Fc8H
Val:
        CALL    L0EEB
        JP      Z,FZero
        LD      E,A
        INC     HL
        INC     HL
        RST     PushNextWord
        LD      H,B
        LD      L,C
        ADD     HL,DE
        LD      B,(HL)
        LD      (HL),D
        EX      (SP),HL
        PUSH    BC
        LD      A,(HL)
        CALL    FIn
        POP     BC
        POP     HL
        LD      (HL),B
        RET     

; Подпрогрмамма ввода с READER. В нашем случае - с магнитофона
	ORG	0FE1H
Reader:
	CALL    0F806h
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        NOP     
        RET     

; Подпрограмма вывода на PUNCHER. В нашем случае - на магнитофон
Puncher2:
	CALL    Puncher
Puncher:
	PUSH    AF
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
L0FFD:  CALL    Puncher
        CALL    Puncher2
        LD      A,(HL)
        CALL    Puncher
        LD      HL,(PROGRAM_BASE)
        EX      DE,HL
        LD      HL,(VAR_BASE)
L100E:  LD      A,(DE)
        INC     DE
        CALL    Puncher
        RST     CompareHLDE
        JP      NZ,L100E
        CALL    Puncher2
        POP     HL
        RST     NextChar
        RET     

        LD      (FACCUM),A
        CALL    New2
L1023:  LD      B,03H
L1025:  CALL    Reader
        CP      0D3H
        JP      NZ,L1023
        DEC     B
        JP      NZ,L1025
        LD      HL,FACCUM
        CALL    Reader
        CP      (HL)
        JP      NZ,L1023
        LD      HL,(PROGRAM_BASE)
L103E:  LD      B,04H
L1040:  CALL    Reader
        LD      (HL),A
        CALL    CheckEnoughMem
        LD      A,(HL)
        OR      A
        INC     HL
        JP      NZ,L103E
        DEC     B
        JP      NZ,L1040
L1051:  LD      (VAR_BASE),HL
        LD      HL,szOK
        CALL    PrintString
        JP      UpdateLinkedList

        CALL    L0645
        LD      A,(DE)
        JP      L0CAB
        CALL    L0642
L1067:  PUSH    DE
        RST     SyntaxCheck
        DB	','
        CALL    L0FB9
        POP     DE
        LD      (DE),A
        RET     

;=================================================================================
;The Math Package
;The 'math package' is a reasonably discrete block of code that provides floating-point arithmetic capability for the rest of BASIC. It also includes some math functions, such as SQR (square root) and is probably the hardest part of BASIC to understand. There are three general reasons for this :
;
;You may have forgotten a lot of the maths you learnt at school. This certainly applied to me : when I began working on this section from first principles, I quickly found myself floundering at the very idea of binary fractions.
;Unless you're a numerical analyst who has reason to distrust conventional hardware/software floating-point support, you probably never needed to think about how floating point worked before now. Modern processors, compilers, and runtime libraries took the pain away years ago, and quite right too.
;Floating point is hard to code. Consider this : Bill Gates is one of the brightest kids in America at the time, but he and his equally brainy pal Paul Allen end up having to hire a third wunderkind, Monte Davidoff, just to do floating point. They needed a specialist to do specialist work, and Monte had done it before.
;Maths Refresher
;The Basics of Bases
;Consider an everyday decimal number such as 317.25. The digits that make up this and every other decimal number represent multiples of powers of ten, all added together:
;
;102	101	100	.	10-1	10-2
;3	1	7	.	2	5
;So writing 317.25 is basically just shorthand for 3*102 + 1*101 + 7*100 + 2*10-1 + 5*10-2. The shorthand form is far more readable, and that's why everybody uses it. At risk of labouring the point, the below table should clarify this.
;
;Digit Position	Digit Value for Position	Decimal Number	Digit value for this number
;2	100	317.25	3 * 100	=	300
;1	10	317.25	1 * 10	=	10
;0	1	317.25	7 * 1	=	7
;-1	1/10	317.25	2 * .1	=	.2
;-2	1/100	317.25	5 * .01	=	.05
;Total:	=	317.25
;Now consider the same number in binary (base two). The decimal number 317.25, expressed in binary, is :
;
;28	27	26	25	24	23	22	21	20	.	2-1	2-2
;1	0	0	1	1	1	1	0	1	.	0	1
;And here's a table like the decimal one above, which should make it completely clear (remember 'bit' is short for 'binary digit') :
;
;Bit Position	Bit Value for Position	Binary Number	Bit value for this number
;8	256	100111101.01	1 * 256	=	256
;7	128	100111101.01	0 * 128	=	0
;6	64	100111101.01	0 * 64	=	0
;5	32	100111101.01	1 * 32	=	32
;4	16	100111101.01	1 * 16	=	16
;3	8	100111101.01	1 * 8	=	8
;2	4	100111101.01	1 * 4	=	4
;1	2	100111101.01	0 * 2	=	0
;0	1	100111101.01	1 * 1	=	1
;-1	1/2	100111101.01	0 * 1/2	=	0
;-2	1/4	100111101.01	1 * 1/4	=	0.25
;Total:	=	317.25
;Mantissas, Exponents, and Scientific Notation
;Now let's think about decimal numbers again. Another way of representing the number 317.25 is like this : 3.1725 * 102. Yes we've split one number into two numbers - we've extracted the number's magnitude and written it seperately. Why is this useful? Well, consider a very small number such as 0.00000000000588. Looking at it now, precisely how small is that? That's a lot of zeros to work through. Also, let's pretend we're using very small numbers like this one in a pen+paper calculation - something like 0.00000000000588 + 0.000000000000291. You'd better be sure you don't miss out a zero when you're working the problem through, or your answer will be off by a factor of 10. It's much easier to have those numbers represented as 5.88 * 10-12 and 2.91* 10-13 (yes the second number had an extra zero - did you spot that?). The same principle applies for very large numbers like 100000000 - it's just easier and less human error prone to keep the magnitudes seperated out when working with such numbers.
;
;It's the smallest of small steps to get from this form of number notation to proper scientific notation. The only difference is how the magnitude is written - in scientific notation we lose the magnitude's base and only write it's exponent part, thusly : 3.1725 E 2. The part that's left of the E, the 3.1725, is called the mantissa. The bit to the right of the E is the exponent.
;
;Mantissas and Exponents in Binary
;Let's go back to considering 317.25 in binary : 100111101.01. Using scientific notation, this is 1.0011110101 E 1000. Remember that both mantissa and exponent are written in binary that exponent value 1000 is a binary number, 8 in decimal.
;
;Why floating point?
;Consider the eternal problem of having a finite amount of computer memory. Not having infinate RAM means we cannot represent an infinite range of numbers. If we have eight bits of memory, we can represent the integers from 0 to 255 only. If we have sixteen, we can raise our range from 0 to 65535, and so on. The more bits we can play with, the larger the range of numbers we can represent. With fractional numbers there is a second problem : precision. Many fractions recur : eg one third in decimal is 0.33333 recurring. Likewise, one tenth is 0.1 in decimal but 0.0001100110011 last four bits recurring in binary.
;
;So any method we choose for storing fractional numbers has to take these two problems into consideration. Bearing this in mind, consider the two possible approaches for storing fractional numbers :
;
;Fixed point. Store the integer part in one field, and the fractional part in another field. It's called fixed point representation since the point (binary or decimal) is always in the same place - between the integer and fractional fields.
;Floating point. Store the mantissa in one field, and the exponent in another field. This way, the point wouldn't be fixed into place - it could be anywhere, as determined by the binary exponent. It would, in fact be, a floating point.
;Why is floating point better than fixed point? Let's say we have 32 bits to play with. Let's use fixed point and assign 16 bits for the integer part and 16 for the fractional part. This allows a range of 0 to 65535.9999 or so, which isn't very good value, range-wise, for 32 bits. OK, lets increase the range - we'll change to using 20 bits for the integer and 12 for the fraction. This gives us a range of 0 to 1,048,575.999ish . Still not a huge range, and since we've only got 12 bits for the fraction we're losing precision - numbers stored this way will be rounded to the nearest 1/4096th.
;
;Now lets try floating point instead. Lets assign a whopping 24 bits for the mantissa and 8 bits for the exponent. 8 bits doesn't sound like much, but this is an exponent after all - with these 8 bits we get a range of -128 to +127 which is roughly 10-38 to to 1038. That's a nice big range! And we get 24 bits of precision too! It's clearly the better choice.
;
;Floating point is not a perfect solution though... adding a very small number to a very large number is likely to produce an erroneous result. For example, go to the BASIC emulator and try PRINT 10000+.1. You get 10000.1 as expected. Now try PRINT 10000+.01 or PRINT 100000+.1. See?
;
;Normalisation
;Normalisation is the process of shifting the mantissa until it is between 0.5 and 1 and adjusting the exponent to compensate. For example, these binary numbers are unnormalised :
;
;101.001
;0.0001
;0.011 E 101
;After normalisation these same binary numbers become :
;
;0.101001 E 11
;0.1 E -11
;0.11 E 100
;blah
;
;How Altair BASIC stored floating point numbers
;There was no industry standard for floating-point number representation back in 1975, so Monte had to roll his own. He decided that 32 bits would allow an adequate range, and defined his floating-point number format like this :
;
;Floating-point number representation in Altair BASIC
;
;The 8-bit exponent field had a bias of 128. This just meant that the stored exponent was stored as 'exponent+128'.
;
;Also, the mantissa was really 24 bits long, but squeezed into 23 bits. How did he save an extra bit of precision? By considering zero as a special case, indicated by exponent zero. Any non-zero number will always have a mantissa with a leading 1. And since the first bit is always going to be 1, why bother storing it?
;
;The intermediate storage of unpacked fp numbers is undefined and seems to be generally done on the fly.
;
;fixme: put example of normalising and denormalising.
;
;
;============================================================================


;FAddOneHalf
;Adds 0.5 to FACCUM.

FAddOneHalf:
	LD      HL,ONE_HALF
FAddFromMem:
	CALL    FLoadBCDEfromMem
        JP      FAddBCDE

FSubFromMem:
	CALL    FLoadBCDEfromMem
        DB	21h			;LD      HL,...
	
	ORG	107dh
;2.2 Addition & Subtraction
;blah
FSub:
	POP	BC
	POP	DE
FSubBCDE:
	CALL    FNegate
FAddBCDE:
	LD      A,B
        OR      A
        RET     Z

        LD      A,(FACCUM+3)
        OR      A
        JP      Z,FLoadFromBCDE
        SUB     B
        JP      NC,L109C
        CPL     
        INC     A
        EX      DE,HL
        CALL    FPush
        EX      DE,HL
        CALL    FLoadFromBCDE
        POP     BC
        POP     DE
L109C:  CP      19H
        RET     NC

        PUSH    AF
        CALL    FUnpackMantissas
        LD      H,A
        POP     AF
        CALL    FMantissaRtMult
        OR      H
        LD      HL,FACCUM
        JP      P,FSubMantissas
        CALL    FAddMantissas
        JP      NC,FRoundUp
        INC     HL
        INC     (HL)
        JP      Z,Overflow
        LD      L,01H
        CALL    L115F
        JP      FRoundUp
	
FSubMantissas:
	XOR     A
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

;2.3 Mantissa Magic
;A group of functions for manipulating mantissas.
;
; 
;
;FNormalise
;Result mantissa in CDEB is normalised, rounded up to CDE, and stored in FACCUM.
;
;If carry set then negate the mantissa. Most users of this function call over this step.	

FNormalise:
	CALL    C,FNegateInt
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
FZero:  XOR     A
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
        JP      Z,FRoundUp
        LD      HL,FACCUM+3
        ADD     A,(HL)
        LD      (HL),A
        JP      NC,FZero
        RET     Z

;Round up the extra mantissa byte.

FRoundUp:
	LD      A,B
L1109:  LD      HL,FACCUM+3
        OR      A
        CALL    M,FMantissaInc
        LD      B,(HL)
        INC     HL
        LD      A,(HL)
        AND     80H
        XOR     C
        LD      C,A
        JP      FLoadFromBCDE

;FMantissaInc
;Increments the mantissa in CDE and handles overflow.
FMantissaInc:
	INC     E
        RET     NZ

        INC     D
        RET     NZ

        INC     C
        RET     NZ

        LD      C,80H
        INC     (HL)
        RET     NZ

Overflow:
	LD      E,ERR_OV
        JP      Error

;FAddMantissas
;Adds the mantissa pointed to by HL to the one in CDE.

FAddMantissas:
	LD      A,(HL)
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

;FNegateInt
;Negate the 32-bit integer in CDEB by subtracting it from zero. Also flips the sign in FTEMP. Used by FAsInteger and FAdd.

FNegateInt:
	LD      HL,FTEMP
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

;FMantissaRtMult
;Shifts the mantissa in CDE right by A places. Note that lost bits end up in B, general practice so we can round up from something later should we need to.

FMantissaRtMult:
	LD      B,00H			;Initialise extra mantissa byte
L114B:  SUB     08H
        JP      C,L1158
        LD      B,E
        LD      E,D
        LD      D,C
        LD      C,00H
        JP      L114B
L1158:  ADD     A,09H
        LD      L,A
RtMultLoop:
	XOR     A
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
        JP      RtMultLoop
	
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
L117E:  RST     FTestSign
        JP      PE,FunctionCallError
        LD      HL,FACCUM+3
        LD      A,(HL)
        LD      BC,8035H
        LD      DE,04F3H
        SUB     B
        PUSH    AF
        LD      (HL),B
        PUSH    DE
        PUSH    BC
        CALL    FAddBCDE
        POP     BC
        POP     DE
        INC     B
        CALL    L121A
        LD      HL,116DH
        CALL    FSubFromMem
        LD      HL,1171H
        CALL    L15FA
        LD      BC,8080H
        LD      DE,0000H
        CALL    FAddBCDE
        POP     AF
        CALL    AddDigit
L11B3:  LD      BC,8031H
        LD      DE,7218H
        DB	21h		;LD      HL,...

;2.4 Multiplication & Division
;blah
;
; 
;
;FMul
;Multiplying two floating point numbers is theoretically simple. All we have to do is add the exponents, multiply the mantissas, and normalise the result. The only problem is that the 8080 didn't have a MUL instruction. Therefore the fundamental logic of multiplication (shift and add) is done by hand in this function. FMul's logic read something like this :
;
;Get lhs and rhs. Exit if rhs=0.
;Add lhs and rhs exponents
;Initialise result mantissa to 0.
;Get rightmost bit of rhs.
;If this bit is set then add the lhs mantissa to the result mantissa.
;Shift result mantissa right one bit.
;Get next bit of rhs mantissa. If not done all 24 bits, loop back to 5.
;Jump to FNormalise
;Alternatively, here's some C++ pseudo-code :
;
;float FMul(float lhs, float rhs)
;{
;  float result = 0;
;  for (int bit=0 ; bit<24 ; bit++) {
;    if (lhs.mantissa & (2^bit)) {
;      result.mantissa += rhs.mantissa;
;    }
;    result.mantissa>>=1;
;  }
;  return FNormalise(result);
;}
;
;(fixme: Show why this works)
	ORG	11BAh
FMul:
	POP	BC
	POP	DE
L11BC:  RST     FTestSign
        RET     Z

        LD      L,00H
        CALL    FExponentAdd
        LD      A,C
        LD      (11F3H),A
        EX      DE,HL
        LD      (11EEH),HL
        LD      BC,0000H
        LD      D,B
        LD      E,B
        LD      HL,L10D3
        PUSH    HL
        LD      HL,FMulOuterLoop
        PUSH    HL
        PUSH    HL
        LD      HL,FACCUM
FMulOuterLoop:
	LD      A,(HL)
        INC     HL
        OR      A
        JP      Z,L1207
        PUSH    HL
        EX      DE,HL
        LD      E,08H
FMulInnerLoop:
	RRA     
        LD      D,A
        LD      A,C
        JP      NC,L11F4
        PUSH    DE
        LD      DE,0000H	; <-- самомодифицирующийся код
        ADD     HL,DE
        POP     DE
        ADC     A,00H		; <-- самомодифицирующийся код
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
        JP      NZ,FMulInnerLoop
        EX      DE,HL
	
PopHLandReturn:
	POP     HL
        RET     

L1207:  LD      B,E
        LD      E,D
        LD      D,C
        LD      C,A
        RET     

;FDivByTen
;Divides FACCUM by 10. Used in FOut to bring the number into range before printing.
FDivByTen:
	CALL    FPush
        LD      BC,8420H
        LD      DE,0000H
        CALL    FLoadFromBCDE
	
	ORG	1218H
FDiv:
L1218:  POP     BC
        POP     DE
L121A:  RST     FTestSign
        JP      Z,DivideByZero
        LD      L,0FFH
        CALL    FExponentAdd
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
FDivLoop:
	PUSH    HL
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
        DB	0D2H	;JP      NC,...
	POP	BC
	POP	HL
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
        JP      NZ,FDivLoop
        PUSH    HL
        LD      HL,FACCUM+3
        DEC     (HL)
        POP     HL
        JP      NZ,FDivLoop
        JP      Overflow
;FExponentAdd
;Here is code common to FMul and FDiv and is called by both of them. It's main job is to add (for FMul) or subtract (for FDiv) the binary exponents of the lhs and rhs arguments, for which on entry L=0 for addition or L=FF respectively.
;
;If BCDE is 0, then we don't need to do anything and can jump to the function exit.	
FExponentAdd:
	LD      A,B
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
        JP      Z,PopHLandReturn
        CALL    FUnpackMantissas
        LD      (HL),A
        DEC     HL
        RET     

L12A8:  RST     FTestSign
        CPL     
        POP     HL
L12AB:  OR      A
L12AC:  POP     HL
        JP      P,FZero
        JP      Overflow

;Multiplies FACCUM by 10. Seems to be here for speed reasons, since this could be done very simply with a call to FMul.
;
;Copy FACCUM to BCDE and return if it's 0.
FMulByTen:
	CALL    FCopyToBCDE
        LD      A,B
        OR      A
        RET     Z

        ADD     A,02H
        JP      C,Overflow
        LD      B,A
        CALL    FAddBCDE
        LD      HL,FACCUM+3
        INC     (HL)
        RET     NZ

        JP      Overflow

;2.5 Sign Magic

;A group of functions for testing and changing the sign of an fp number.

;FTestSign_tail
;When FACCUM is non-zero, RST FTestSign jumps here to get the sign as an integer : 0x01 for positive, 0xFF for negative.
	ORG	12cah

FTestSign_tail:
	LD	A,(FACCUM+2)
	DB	0FEH	;CP	2FH

;InvSignToInt
;Inverts the sign byte in A before falling into SigntoInt.
;
;Simply invert A.
InvSignToInt:
	CPL

;SignToInt
;Converts the sign byte in A to 0x01 for positive, 0xFF for negative.


;Get bit 7 into carry flag and subtract from itself with carry. If A was +ve then it is now 0, whereas if A was -ve then A is now FF.
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

Sgn:	RST     FTestSign

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
        JP      FNormalise

;Abs
;FACCUM = |FACCUM|.
;
;Return if FACCUM is already positive, otherwise fall into FNegate to make it positive.
	ORG	12e8h
Abs:
        RST     FTestSign
        RET     P

FNegate:
	LD      HL,FACCUM+2	;024FH
        LD      A,(HL)
        XOR     80H
        LD      (HL),A
        RET     

;2.6 Moving FACCUM about
;A group of functions for loading, copying, and pushing FACCUM.

FPush:
	EX      DE,HL
        LD      HL,(FACCUM)
        EX      (SP),HL
        PUSH    HL
        LD      HL,(FACCUM+2)
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        RET     

;FLoadFromMem
;FLoadFromMem loads FACCUM with the fp number pointed to by HL. It does this by calling a function to load BCDE with the in-memory number, then falls into FLoadFromBCDE.

FLoadFromMem:
	CALL    FLoadBCDEfromMem

;FLoadFromBCDE
;Loads FACCUM with BCDE.
FLoadFromBCDE:
	EX      DE,HL
        LD      (FACCUM),HL
        LD      H,B
        LD      L,C
        LD      (FACCUM+2),HL
        EX      DE,HL
        RET     
	
;FCopyToBCDE and FLoadBCDE

FCopyToBCDE:
	LD      HL,FACCUM

FLoadBCDEfromMem:
	LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
L1317:  INC     HL
        RET     

;FCopyToMem
;Copies FACCUM to another place in memory pointed to by HL.
FCopyToMem:
	LD      DE,FACCUM
L131C:  LD      B,04H
FCopyLoop:
	LD      A,(DE)
        LD      (HL),A
        INC     DE
        INC     HL
        DEC     B
        JP      NZ,FCopyLoop
        RET     

;2.7 Unpacking & Comparison
;Two functions : the first is for unpacking the mantissas of two floating-point numbers, the second is for comparing two floating-point numbers.
;
; 
;FUnpackMantissas
;Unpacks the mantissas of FACCUM and BCDE. This is simple enough - we just restore the missing most-significant bit, invariably a 1 (see tech note). Unfortunately, doing this loses the sign bits of both packed numbers.
;
;To compensate for this, a combination of both signs is returned. Duing the function FACC's sign is negated and later xor'ed with BCDE's sign, and returned in bit 7 of A. The effect of this is when the function returns, A is +ve if the signs mismatched, or -ve if the signs matched.
;
;FACC	Negated
;FACC	BCDE	Result
;after XOR
;+	-	+	-
;+	-	-	+
;-	+	+	+
;-	+	-	-


FUnpackMantissas:
	LD      HL,FACCUM+2
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

;FCompare
;Compares FACCUM to BCDE, with the result being returned in A as follows :

;FACCUM > BCDE, A = 0x01.
;FACCUM < BCDE, A = 0xFF.
;FACCUM = BCDE, A = 0.

;If BCDE is zero, then we don't need to compare and can just return via FTestSign.
FCompare:
	LD      A,B
        OR      A
        JP      Z, FTestSign
        LD      HL,InvSignToInt
        PUSH    HL
        RST     FTestSign
        LD      A,C
        RET     Z

        LD      HL,FACCUM+2
        XOR     (HL)
        LD      A,C
        RET     M

        CALL    FIsEqual
        RRA     
        XOR     C
        RET     

;Test for equality between BCDE and FACCUM.
FIsEqual:
	INC     HL
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

;2.8 Converting to Integer
;blah
;
; 
;FAsInteger
;Returns the integer part of FACCUM in CDE.
;
;Return with BCDE=0 if A=0.
FAsInteger:
	LD      B,A
        LD      C,A
        LD      D,A
        LD      E,A
        OR      A
        RET     Z

        PUSH    HL
        CALL    FCopyToBCDE
        CALL    FUnpackMantissas
        XOR     (HL)
        LD      H,A
        CALL    M,FMantissaDec
        LD      A,98H
        SUB     B
        CALL    FMantissaRtMult
        LD      A,H
        RLA     
        CALL    C,FMantissaInc
        LD      B,00H
        CALL    C,FNegateInt
        POP     HL
        RET     


FMantissaDec:
	DEC     DE
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
	LD      HL,FACCUM+3
        LD      A,(HL)
        CP      98H
        LD      A,(FACCUM)
        RET     NC

        LD      A,(HL)
        CALL    FAsInteger
        LD      (HL),98H
        LD      A,E
        PUSH    AF
        LD      A,C
        RLA     
        CALL    FNormalise
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

;2.9 Reading Numbers
;Function that reads a floating-point number from ASCII text.

;FIn
;Reads a string and converts it to a floating point number in FACCUM.
;The first thing we do is some initialisation.
;
;Все регистры портятся
;
;На входе HL содержит указатель на строку.
;A содержит копию первого символа.
;C = 255 если точка не обнаружена, 0 если да
;B = число цифр после точки
;E = экспонента

FIn:	CP      '-'		; '-'
        PUSH    AF		; Сохраняем знак в стеке
        JP      Z,SkipSign
        CP      '+'		; '+'
        JP      Z,SkipSign
;Decrement string ptr so it points to just before the number, also set FACCUM to 0.
        DEC     HL
SkipSign:
	CALL    FZero
        LD      B,A
        LD      D,A
        LD      E,A
        CPL     		; C=decimal_point_done (0xFF for no, 0x00 for yes)
        LD      C,A

;This is the head of the loop that processes one character of ASCII text at a time.
;
;Get next ASCII character and if it's a digit (as determined by carry flag) then jump down to ProcessDigit.
FInLoop:
	RST     NextChar
        JP      C,ProcessDigit
        CP      '.'		; '.'
        JP      Z,PointFound
        CP      'E'		; 'E'
        JP      NZ,ScaleResult
        RST     NextChar
        PUSH    HL
        LD      HL,NextExponentDigit
        EX      (SP),HL
        DEC     D
        CP      TK_MINUS		; '-'
        RET     Z		; JP NextExponentDigit

        CP      '-'		; '-'
        RET     Z		; JP NextExponentDigit

        INC     D
        CP      '+'		; '+'
        RET     Z		; JP NextExponentDigit

        CP      TK_PLUS		; '+'
        RET     Z		; JP NextExponentDigit

        POP     AF
        DEC     HL
NextExponentDigit:
	RST     NextChar
        JP      C,DoExponentDigit
        INC     D
        JP      NZ,ScaleResult
        XOR     A
        SUB     E
        LD      E,A
        INC     C
PointFound:
	INC     C
        JP      Z,FInLoop
ScaleResult:
	PUSH    HL
        LD      A,E
        SUB     B
DecimalLoop:
	CALL    P,DecimalShiftUp
        JP      P,DecimalLoopEnd
        PUSH    AF
        CALL    FDivByTen
        POP     AF
        INC     A
DecimalLoopEnd:
	JP      NZ,DecimalLoop
        POP     DE
        POP     AF
        CALL    Z,FNegate
        EX      DE,HL
        RET     

; Helper function for shifting the result decimally up one place. We only do this if A !=0, and at the end we decrement A before returning.

DecimalShiftUp:
	RET     Z
L1428:  PUSH    AF
        CALL    FMulByTen
        POP     AF
        DEC     A
        RET     

ProcessDigit:
	PUSH    DE
        LD      D,A
        LD      A,B
        ADC     A,C
        LD      B,A
        PUSH    BC
        PUSH    HL
        PUSH    DE
        CALL    FMulByTen
        POP     AF
        SUB     '0'
        CALL    AddDigit
        POP     HL
        POP     BC
        POP     DE
        JP      FInLoop
	
AddDigit:
	CALL    FPush
        CALL    FCharToFloat
	
	ORG	144ch
FAdd:
        POP     BC
        POP     DE
        JP      FAddBCDE
	
DoExponentDigit:
	LD      A,E
        RLCA    
        RLCA    
        ADD     A,E
        RLCA    
        ADD     A,(HL)
        SUB     '0'
        LD      E,A
        JP      NextExponentDigit
	
;2.10 Printing Numbers
;Functions for printing floating-point numbers.

;PrintIN
;Prints "IN " and falls into PrintInt. Used by the error handling code to print stuff like "?SN ERROR IN 50".
	
		
PrintIN:
	PUSH    HL
        LD      HL,szIn
        CALL    PrintString
        POP     HL
		
;PrintInt
;Promotes the integer in HL to a floating-point number in FACC, sets the return address to PrintSz-1, and falls into FOut.
;The promotion from integer to float is interesting : the integer starts off by occupying the least significant bits of the
;mantissa CDE. The exponent in B is set to 24 (because, thus giving us an unnormalised but perfectly valid floating-point
;number in no time at all! Took me a while to see that...

PrintInt:
	EX      DE,HL
        XOR     A
        LD      B,98H
        CALL    L12DA
        LD      HL,0D92H
        PUSH    HL
;FOut
;Prints a floating point number to the terminal.
;
;Set HL to FBUFFER, which is where FACCUM gets printed to.	
FOut:  LD      HL,0252H
        PUSH    HL
        RST     FTestSign
        LD      (HL),20H
        JP      P,L147C
        LD      (HL),2DH
L147C:  INC     HL
        LD      (HL),30H
        JP      Z,L1525
        PUSH    HL
        CALL    M,FNegate
        XOR     A
        PUSH    AF
        CALL    ToUnder1000000
L148B:  LD      BC,9143H
        LD      DE,4FF8H
        CALL    FCompare
        JP      PO,L14A8
        POP     AF
        CALL    L1428
        PUSH    AF
        JP      L148B
L149F:  CALL    FDivByTen
        POP     AF
        INC     A
        PUSH    AF
        CALL    ToUnder1000000
L14A8:  CALL    FAddOneHalf
        INC     A
        CALL    FAsInteger
        CALL    FLoadFromBCDE
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
        LD      DE,DECIMAL_POWERS
L14C9:  DEC     B
        LD      (HL),2EH
        CALL    Z,L1317
        PUSH    BC
        PUSH    HL
        PUSH    DE
        CALL    FCopyToBCDE
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
        CALL    FAddMantissas
        INC     HL
        CALL    FLoadFromBCDE
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

;ToUnder1,000,000
;Divides FACCUM by ten until it's less than 1,000,000. This function is semi-recursive... if it needs to recurse (ie

ToUnder1000000:
	LD      BC,9474H
        LD      DE,23F7H
        CALL    FCompare
        POP     HL
        JP      PO,L149F
        JP      (HL)

ONE_HALF:
        DB 0,0,0,80h		;Constant value 0.5, used by FRoundUp

;DECIMAL_POWERS
;Table of powers of ten.

DECIMAL_POWERS:
	DB	0A0h, 86h, 01h		;DD 100000
	DB	010h, 27h, 00h        	;DD 10000
	DB	0E8h, 03h, 00h        	;DD 1000
	DB	064h, 00h, 00h        	;DD 100
	DB	00Ah, 00h, 00h        	;DD 10
	DB	001h, 00h, 00h        	;DD 1
	
	
L154F:  LD      HL,FNegate
        EX      (SP),HL
        JP      (HL)
	
	ORG	1554h
Sqr:
        CALL    FPush
        LD      HL,1539H
        CALL    FLoadFromMem

	ORG	155dh
FPower:
        POP     BC
        POP     DE
        RST     FTestSign
        JP      Z,L1599
        LD      A,B
        OR      A
        JP      Z,L10E9
        PUSH    DE
        PUSH    BC
        LD      A,C
        OR      7FH
        CALL    FCopyToBCDE
        JP      P,L1581
        PUSH    DE
        PUSH    BC
        CALL    Int
        POP     BC
        POP     DE
        PUSH    AF
        CALL    FCompare
        POP     HL
        LD      A,H
        RRA     
L1581:  POP     HL
        LD      (FACCUM+2),HL
        POP     HL
        LD      (FACCUM),HL
        CALL    C,L154F
        CALL    Z,FNegate
        PUSH    DE
        PUSH    BC
        CALL    L117E
        POP     BC
        POP     DE
        CALL    L11BC
	
	ORG	1599h
Exp:
L1599:  CALL    FPush
        LD      BC,8138H
        LD      DE,0AA3BH
        CALL    L11BC
        LD      A,(FACCUM+3)
        CP      88H
        JP      NC,L12A8
        CALL    Int
        ADD     A,80H
        ADD     A,02H
        JP      C,L12A8
        PUSH    AF
        LD      HL,116DH
        CALL    FAddFromMem
        CALL    L11B3
        POP     AF
        POP     BC
        POP     DE
        PUSH    AF
        CALL    FSubBCDE
        CALL    FNegate
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
L15FA:  CALL    FPush
        LD      DE,11BAH
        PUSH    DE
        PUSH    HL
        CALL    FCopyToBCDE
        CALL    L11BC
        POP     HL
L1609:  CALL    FPush
        LD      A,(HL)
        INC     HL
        CALL    FLoadFromMem
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
        CALL    FLoadBCDEfromMem
        PUSH    HL
        CALL    FAddBCDE
        POP     HL
        JP      L1612

	ORG	162ah
Rnd:
	RST     FTestSign
        JP      M,L1647
        LD      HL,RND_SEED
        CALL    FLoadFromMem
        RET     Z

        LD      BC,9835H
        LD      DE,447AH
        CALL    L11BC
        LD      BC,6828H
        LD      DE,0B146H
        CALL    FAddBCDE
L1647:  CALL    FCopyToBCDE
        LD      A,E
        LD      E,C
        LD      C,A
        LD      (HL),80H
        DEC     HL
        LD      B,(HL)
        LD      (HL),80H
        CALL    L10D3
        LD      HL,RND_SEED
        JP      FCopyToMem

RND_SEED:	
        LD      D,D
        RST     00H
        LD      C,A
        ADD     A,B
	
	ORG	1660H
Cos:
L1660:  LD      HL,16A6H
        CALL    FAddFromMem
	ORG	1666h
Sin:
L1666:  CALL    FPush
        LD      BC,8349H
        LD      DE,0FDBH
        CALL    FLoadFromBCDE
        POP     BC
        POP     DE
        CALL    L121A
        CALL    FPush
        CALL    Int
        POP     BC
        POP     DE
        CALL    FSubBCDE
        LD      HL,16AAH
        CALL    FSubFromMem
        RST     FTestSign
        SCF     
        JP      P,L1692
        CALL    FAddOneHalf
        RST     FTestSign
        OR      A
L1692:  PUSH    AF
        CALL    P,FNegate
        LD      HL,16AAH
        CALL    FAddFromMem
        POP     AF
        CALL    NC,FNegate
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
        RST     NextChar
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
        CALL    FPush
        CALL    L1666
        POP     BC
        POP     HL
        CALL    FPush
        EX      DE,HL
        CALL    FLoadFromBCDE
        CALL    L1660
        JP      L1218

	ORG	16D8h
Atn:
        RST     FTestSign
        CALL    M,L154F
        CALL    M,FNegate
        LD      A,(FACCUM+3)
        CP      81H
        JP      C,L16F3
        LD      BC,8100H
        LD      D,C
        LD      E,C
        CALL    L121A
        LD      HL,FSubFromMem
        PUSH    HL
L16F3:  LD      HL,16FDH
        CALL    L15FA
        LD      HL,16A6H
        RET     

        ADD     HL,BC
        LD      C,D
        RST     NextChar
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
        RST     FTestSign
        CALL    L0649
        LD      A,(DE)
        JP      L0CAB
	
	ORG	172CH
Poke:
        CALL    L0966
        RST     FTestSign
        CALL    L0649
        JP      L1067
	
	ORG	1736h
Usr:
        RST     FTestSign
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
InitLoop:
	LD      A,(HL)
        OR      A			; CP 0
        JP      Z,Main
        LD      C,(HL)
        INC     HL
        CALL    0F809h
        JP      InitLoop
		
szHello:		DB		1Fh, 0Dh, 0Ah, 2Ah, 4Dh, 69h, 6Bh, 72h, 4Fh, 2Fh
			DB		38h, 30h, 2Ah, 20h, 42h, 41h, 53h, 49h, 43h, 00h

	ORG	176ah
Cur:
L176A:  CALL    L0FB9
        LD      (1957H),A
        RST     SyntaxCheck
        DB	','
        CALL    L0FB9
        LD      (1958H),A
        CP      20H
        JP      NC,FunctionCallError
        LD      A,(1957H)
        CP      40H
        JP      NC,FunctionCallError
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
        DB	','
        CALL    L0FB9
        LD      (1955H),A
        RST     SyntaxCheck
        DB	','
        CALL    L0FB9
        LD      (1956H),A
L17DD:  LD      A,(1954H)
        CP      80H
        JP      NC,FunctionCallError
        LD      A,(1955H)
        CP      40H
        JP      NC,FunctionCallError
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
        DB	','
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
L18F2:  CALL    Puncher
        DEC     L
        JP      NZ,L18F2
        POP     HL
        PUSH    HL
        LD      A,0E6H
        CALL    Puncher
        LD      A,0D3H
        JP      L0FFD

	ORG	1905H
Mload:
        LD      (FACCUM),A
        CALL    New2
        LD      B,03H
        LD      A,0FFH
        CALL    Reader
        CP      0D3H
        JP      Z,L1923
L1917:  LD      B,03H
L1919:  LD      A,08H
        CALL    Reader
        CP      0D3H
        JP      NZ,L1917
L1923:  DEC     B
        JP      NZ,L1919
        LD      HL,FACCUM
        LD      A,08H
        CALL    Reader
        CP      (HL)
        JP      NZ,L1917
        LD      HL,(PROGRAM_BASE)
L1936:  LD      B,03H
L1938:  LD      A,08H
        CALL    Reader
        LD      (HL),A
        CALL    CheckEnoughMem
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

