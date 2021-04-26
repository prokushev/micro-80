		CPU		8080
; НАЧАЛЬНЫЙ АДРЕС ДЛЯ ИМИТАТОРА
; ДАННОЕ НАЗНАЧЕНИЕ - ДЛЯ ПЭВМ "МИКРОША"
BASE	EQU		7400H
; ПОДПРОГРАММЫ ВВОДА-ВЫВОДА РЕЗИДЕНТНОГО МОНИТОРА
MONITOR	EQU		0F800H	;ЗАПУСК МОНИТОРА
CO		EQU		0F809H	;ВЫВОД НА ЭКРАН
CI		EQU		0F803H	;ВВОД С КЛАВИАТУРЫ
CSTS	EQU		0F812H	;СТАТУС КЛАВИАТУРЫ
LO		EQU		CO		;ВЫВОД НА ПРИНТЕР
						;(НЕТ ПРИНТЕРА)
;-------------------------------------------------
;ПРОГРАММА ПЕРЕМЕЩЕНИЯ ИМИТАТОРА ДОС
		ORG		100H
		
		JMP		START
		DB		20H		; В ЭТОЙ ЯЧЕЙКЕ НЕОБХОДИМО
						;ПОМЕСТИТЬ РАЗМЕР .COM ФАЙЛА
						;В СТРАНИЦАХ (256 БАЙТ)
;СНАЧАЛА ПРОИЗВОДИТСЯ ИНИЦИАЛИЗАЦИЯ РАБОЧИХ
;ЯЧЕЕК ИМИТАТОРА НА ПЕРВОЙ СТРАНИЦЕ ОЗУ

START:	MVI		A, 0C3H
		STA		0
		LXI		H, BIOS
		SHLD	1
		STA		5
		LXI		J, BDOS
		SHLD	6
		XRA		A
		STA		3
		STA		4
;ОЧИСТИТЬ БЛОКИ УПРАВЛЕНИЙ ФАЙЛОМ
		LXI		H, 40H
FILLFCB:	MVI		M, 20H
		INX		H
		MOV		A, H
		CPI		1
		JNZ		FILLFCB
		XRA		A
		STA		5CH
		STA		6CH
		LXI		SP, 100H
;ТЕПЕРЬ ИМИТАТОР ДОС ПЕРЕМЕЩАЕТСЯ В
;ТРЕБУЕМОЕ МЕСТО ПАМЯТИ
		LXI		H, 1A0H	;НАЧАЛЬНЫЙ АДРЕС
						;КОПИИ ИМИТАТОРА
		LXI		B, BDOS	;НАЧАЛЬНЫЙ АДРЕС
						;ИМИТАТОРА БДОС
MOVCPM:	MOV		A, M
		STAX	B
		INX		H
		INX		B
		MOV		A, H
		CPI		4		;ПЕРЕСЫЛКА ОТ 1A0H
						;ДО 2FFH
		JNZ		MOVCPM
;ТЕПЕРЬ В СВОЕ МЕСТО ПЕРЕМЕЩАЕТСЯ
;ПРОГРАММА ПЕРЕСЫЛКИ .COM ФАЙЛА
		LXI		H, 160H
		LXI		B, 80H
MOMOV:	MOV		A, MOMOV
		STAX	B
		INX		H
		INX		B
		MOB		A, L
		CPI		0A0H
		JNZ		MOMOV
		JMP		80H		;ЗАПУСК ПРОГРАММЫ
						;ПЕРЕМЕЩЕНИЯ
						;.COM ФАЙЛА
;-----------------------------------------
;"ОБРАЗ" ПРОГРАММЫ ПЕРЕМЕЩЕНИЯ .COM ФАЙЛА
;LDA 103H: LXI H,100H:LXI B,300H: MVI E,0:
;MOV D,A: LDAX B: MOV M,A: INX H: INX B:
;DCX D: MOV A,D: ORA E: JNZ CIK: JMP 100H
		ORG		160H
		
		DB		3AH,03H,01H,21H,00H,01H
		DB		01H,00H,03H,1EH,00H,57H
		DB		0AH,77H,23H,03H,1BH,7AH
		DB		0B3H,0C2H,8CH,00H,0C3H,0,1
		
;-----------------------------------------
;ПРОГРАММА "ИМИТАТОР ДОС"
;-----------------------------------------
		ORG		BASE
		
;СОХРАНИТЬ СОСТОЯНИЕ РЕГИСТРОВ
;ПРИКЛАДНОЙ ПРОГРАММЫ
BDOS:	SHLD	HLL		; HL
		XCHG
		SHLD	DEL		; DE
		XCHG
		MOV		H,B
		MOV		L,C
		SHLD	BCL		; BC
		LXI		H, 0
		DAD		SP
		SHLD	SPL		; SP
		LXI		SP,BASE+200H
		PUSH	PSW
		MOV		A,C
		CPI		13
		JNC		MRET	;ИГНОРИРОВАТЬ
						;ОБРАЩЕНИЕ К ДИСКУ
;ВЫЧИСЛЯЕМ АДРЕС ПОДПРОГРАММЫ ОБСЛУЖИВАНИЯ
;СИСТЕМНЫХ ВЫЗОВОВ ДОС
		MVI		H, 0
		MOV		L, C
		DAD		H
		MOV		B, H
		MOV		C, L
		LXI		H,TABL
		DAD		B
		MOV		C,M
		INX		H
		MOV		H,M
		MOV		L,C
;ЗАПУСК СООТВЕТСТВУЮЩЕЙ ПОДПРОГРАММЫ
		PCHL
;-----------------------------------------
;ТАБЛИЦА АДРЕСОВ ПОДПРОГРАММЫ
;НЕОБСЛУЖИВАЕМЫЕ СИСТЕМНЫЕ ВЫЗОВЫ
;ПРОСТО ИГНОРИРУЮТСЯ
;-----------------------------------------
TABL:	DW		FSYSR	;ФУНКЦИЯ 0
		DW		FCONIN	;ФУНКЦИЯ 1
		DW		FCONO	;ФУНКЦИЯ 2
		DW		FRI		;ФУНКЦИЯ 3
		DW		FPO		;ФУНКЦИЯ 4
		DW		FLO		;ФУНКЦИЯ 5
		DW		FDCIO	;ФУНКЦИЯ 6
		DW		FGIOB	;ФУНКЦИЯ 7
		DW		FSIOB	;ФУНКЦИЯ 8
		DW		FPRST	;ФУНКЦИЯ 9
		DW		FRCB	;ФУНКЦИЯ 10
		DW		FGCS	;ФУНКЦИЯ 11
		DW		FRVN	;ФУНКЦИЯ 12
;ВОЗВРАТ В ПРИКЛАДНУЮ ПРОГРАММУ
;СЛЕДУЮЩИЕ ФУНКЦИИ ИГНОРИРУЮТСЯ
FSYSR:	;ФУНКЦИЯ 0
FRI:	;ФУНКЦИЯ 3
FPO:	;ФУНКЦИЯ 4
FLO:	;ФУНКЦИЯ 5
FGIOB:	;ФУНКЦИЯ 7
FSIOB:	;ФУНКЦИЯ 8
;ВОССТАНОВИТЬ СОДЕРЖИМОЕ РЕГИСТРОВ
MRET:	POP		PSW
MRET1:	LHLD	SPL
		SPHL
		LHLD	DEL
		