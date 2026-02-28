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
	CPU		8080
		
		Z80SYNTAX	EXCLUSIVE

FixInitBug      EQU TRUE

DefaultRdWrConst    EQU 03854H
ScreenHeight        EQU 20H
ScreenWidth         EQU 40H
SymbolBufEndHI      EQU 0F0H
CursorBufferStart   EQU 0E000H
SymbolBufferStart   EQU 0E800H

        ORG 0F000h
word_F000:      DS 75Ah
CursorAddress:  DS 2
TapeReadConst:  DS 1     
TapeWriteConst: DS 1     
CursorVisible:  DS 1    ; Показать/скрыть курсор: ESC $1B+$61/$1B+$62
EscSequenceState: DS 1
LastKeyStatus:  DS 2    ; H - последняя нажатая клавиша, L - счетчик автоповтора
RST6_VAR3:      DS 2    
RST6_VAR1:      DS 2    
        DS 4
F7FE_storedHere:DS 2    ; Здесь хранится $F7FE
RST6_VAR2:      DS 2    
        DS 3
RST6_RUN_Var1:  DS 2    
RST6_RUN_Var2:  DS 1    
JMPcommand:     DS 1    ; Здесь хранится команда $C3 "JMP"
JMPaddress:     DS 2    
word_F777:      DS 2
word_F779:      DS 2
byte_F77B:      DS 1    
TapeReadVAR:    DS 1
HookActive:     DS 1    ; Флаг активности обработчика прерываний (не 0 = активно)
HookJmp:        DS 1    ; Здесь хранится $C3 "JMP" для обработчика
HookAddress:    DS 2    
FreeMemAddr:    DS 2
CmdLineBuffer:  DS 7Ch  

; ===========================================================================
; Начало исполняемого кода
        ORG 0F800h
        JP    ColdReset     ; Точка входа при холодном старте

        JP    InputSymbol   ; Ввод символа с клавиатуры

        JP    TapeReadByte  ; Чтение байта с магнитофона

        JP    PrintCharFromC ; Печать символа из регистра C

        JP    TapeWriteByte ; Запись байта на магнитофон

        JP    HookJmp       ; Прямой вызов обработчика печати символа

        JP    GetKeyboardStatus ; Проверка состояния клавиатуры

        JP    PrintHexByte  ; Печать байта в HEX

        JP    PrintString   ; Печать строки

        JP    ReadKeyCode   ; Чтение кода клавиши

        JP    GetCursorPos  ; Получение позиции курсора

        JP    ReadVideoRAM  ; Чтение видеопамяти

        JP    TapeReadBlock ; Чтение блока с магнитофона

        JP    TapeWriteBlock ; Запись блока на магнитофон

        JP    CalcChecksum  ; Вычисление контрольной суммы

        RET			; Инициализация обновления экрана (заглушка)

        DW    0
        JP    GetFreeMemAddr ; Получение адреса свободной памяти

        JP    SetFreeMemAddr ; Установка адреса свободной памяти

; ---------------------------------------------------------------------------
; Холодный старт системы
ColdReset:              
        LD    SP, 0F800h   ; Инициализация указателя стека

        IF    ~~FixInitBug
        ; Вывод приветственного сообщения (оригинальное расположение)
        LD    HL, WelcomeMsg ; "\x1F\nm/80k "
        CALL  PrintString
        ENDIF

        ; Очистка области $F75D..$F7A2
        LD    HL, 0F75Dh
        LD    DE, 0F7A2h
        LD    BC, 0
        CALL  DirectiveFill

        ; Настройка обработчика прерываний
        LD    A, 0C3h      ; Код инструкции "JMP"
        LD    (HookJmp), A

        IF    FixInitBug
        ; Вывод приветственного сообщения (исправленное расположение)
        LD    HL, WelcomeMsg ; "\x1F\nm/80k "
        CALL  PrintString
        ENDIF

        ; Поиск конца оперативной памяти
        LD    HL, 0

ContinueSearch:             
        LD    C, (HL)      ; Сохраняем текущее значение
        LD    A, 55h       ; Тестовый паттерн 1
        LD    (HL), A
        XOR   (HL)
        LD    B, A
        LD    A, 0AAh      ; Тестовый паттерн 2
        LD    (HL), A
        XOR   (HL)
        OR    B
        JP    NZ, RamEndFound ; Если память не отвечает - конец ОЗУ

        ; Восстановление значения и переход к следующей ячейке
        LD    (HL), C
        INC   HL
        LD    A, H
        CP    0E0h         ; Проверка достижения видеопамяти ($E000)
        JP    Z, RamEndFound

        JP    ContinueSearch

; ---------------------------------------------------------------------------
; Точка входа для теплого старта RK/86
RK86WarmReset:              
        JP    WarmReset    ; Вектор теплого старта RK/86 ($F86C)

RamEndFound:                
        DEC   HL           ; Корректировка последнего адреса ОЗУ
        LD    (FreeMemAddr), HL
        CALL  PrintHexWord ; Печать верхнего адреса свободной памяти

        ; Настройка констант по умолчанию
        LD    HL, DefaultRdWrConst
        LD    (TapeReadConst), HL
        LD    HL, DummyHook
        LD    (HookAddress), HL
        LD    HL, 0F7FEh   ; Сохранение системной переменной
        LD    (F7FE_storedHere), HL

; ---------------------------------------------------------------------------
; Теплый старт системы
WarmReset:                 
        LD    A, 83h       ; Инициализация контроллера BB55
        OUT   (4), A
        LD    (CursorVisible), A ; Включение отображения курсора
        LD    A, 0C3h      ; Код инструкции "JMP"
        LD    (JMPcommand), A

; ---------------------------------------------------------------------------
; Обработка директив монитора
ProcessDirective:           
        LD    SP, 0F800h   ; Восстановление стека
        LD    HL, DirectivePrompt ; "\r\n-->"
        CALL  PrintString

        CALL  InputDirective ; Ввод директивы

        LD    HL, RK86WarmReset
        PUSH  HL           ; Возврат на теплый старт
        LD    HL, CmdLineBuffer
        LD    A, (HL)
        CP    'X'          ; Директива регистров?
        JP    Z, DirectiveRegisters

        ; Разбор параметров директив
        PUSH  AF
        CALL  sub_F952

        LD    HL, (word_F779)
        LD    C, L
        LD    B, H
        LD    HL, (word_F777)
        EX    DE, HL
        LD    HL, (JMPaddress)
        POP   AF

        ; Диспетчеризация директив
        CP    'D'
        JP    Z, DirectiveDump

        CP    'C'
        JP    Z, DirectiveCompare

        CP    'F'
        JP    Z, DirectiveFill

        CP    'S'
        JP    Z, DirectiveSearch

        CP    'T'
        JP    Z, DirectiveCopy

        CP    'M'
        JP    Z, DirectiveModify

        CP    'G'
        JP    Z, DirectiveRun

        CP    'I'
        JP    Z, DirectiveTapeInp

        CP    'O'
        JP    Z, DirectiveTapeOut

        CP    'W'
        JP    Z, DirectiveSearchWrd

        CP    'A'
        JP    Z, DirectiveHookAdr

        CP    'H'
        JP    Z, DirectiveTapeConst

        CP    'R'
        JP    Z, DirectiveReadROM

        JP    SyntaxError   ; Неизвестная директива

; ---------------------------------------------------------------------------
; Обработка Backspace
ProcessBackspace:           
        LD    A, CmdLineBuffer & 0FFH
        CP    L
        JP    Z, GotoCmdLineBegin ; Уже в начале строки

        PUSH  HL
        LD    HL, BackspaceStr ; "\b \b"
        CALL  PrintString

        POP   HL
        DEC   HL
        JP    InputNextSymbol

; ---------------------------------------------------------------------------
; Ввод директивы
InputDirective:             
        LD    HL, CmdLineBuffer

GotoCmdLineBegin:           
        LD    B, 0         ; Флаг пустой строки

InputNextSymbol:            
        CALL  InputSymbol   ; Ввод символа
        CP    7Fh           ; Backspace?
        JP    Z, ProcessBackspace
        CP    8             ; Ctrl+H?
        JP    Z, ProcessBackspace

        CALL  NZ, PrintCharfromA ; Эхо-печать

        LD    (HL), A       ; Сохранение в буфер
        CP    0Dh           ; Enter?
        JP    Z, ProcessReturn
        CP    '.'           ; Повтор последней директивы?
        JP    Z, ProcessDirective

        LD    B, 0FFh       ; Установка флага непустой строки
        LD    A, 0A2h       ; Проверка переполнения буфера
        CP    L
        JP    Z, SyntaxError

        INC   HL
        JP    InputNextSymbol

ProcessReturn:              
        LD    A, B
        RLA                 ; Проверка пустой строки
        LD    DE, CmdLineBuffer
        LD    B, 0
        RET

; ---------------------------------------------------------------------------
; Печать строки (HL=адрес строки)
PrintString:                
        LD    A, (HL)       ; Загрузка символа
        AND   A             ; Проверка на 0 (конец строки)
        RET  Z              ; Возврат если конец

        CALL  PrintCharfromA ; Печать символа
        INC   HL            ; Следующий символ
        JP    PrintString

; ---------------------------------------------------------------------------
; Разбор параметров директив
sub_F952:                   
        LD    HL, JMPaddress
        LD    DE, byte_F77B
        LD    C, 0
        CALL  DirectiveFill ; Заполнение нулями

        LD    DE, CmdLineBuffer+1
        CALL  sub_F980      ; Разбор первого параметра

        LD    (JMPaddress), HL
        LD    (word_F777), HL
        RET  C             ; Возврат если конец строки

        LD    A, 0FFh
        LD    (byte_F77B), A
        CALL  sub_F980      ; Разбор второго параметра

        LD    (word_F777), HL
        RET  C             ; Возврат если конец строки

        CALL  sub_F980      ; Разбор третьего параметра

        LD    (word_F779), HL
        RET  C             ; Возврат если конец строки
        JP    SyntaxError   ; Слишком много параметров

; ---------------------------------------------------------------------------
; Разбор шестнадцатеричного числа (DE=адрес строки)
sub_F980:                   
        LD    HL, 0         ; Инициализация результата

loc_F983:                   
        LD    A, (DE)       ; Чтение символа
        INC   DE
        CP    0Dh           ; Проверка конца строки
        JP    Z, loc_F9B4

        CP    ','           ; Разделитель параметров?
        RET  Z
        CP    ' '           ; Пропуск пробелов
        JP    Z, loc_F983

        ; Преобразование цифры
        SUB   '0'
        JP    M, SyntaxError ; Недопустимый символ

        CP    0Ah
        JP    M, loc_F9A8   ; Цифра 0-9

        CP    11h
        JP    M, SyntaxError ; Недопустимый символ

        CP    17h
        JP    P, SyntaxError

        SUB   7             ; Коррекция для букв A-F

loc_F9A8:                   
        LD    C, A          ; Сохранение цифры
        ADD   HL, HL        ; HL *= 16
        ADD   HL, HL
        ADD   HL, HL
        ADD   HL, HL
        JP    C, SyntaxError ; Переполнение

        ADD   HL, BC        ; Добавление цифры
        JP    loc_F983

loc_F9B4:                   
        SCF                 ; Установка флага Carry (конец строки)
        RET

; ===========================================================================
; Служебные функции
; ===========================================================================

; ---------------------------------------------------------------------------
; Сравнение HL и DE
Compare_HL_DE:              
        LD    A, H
        CP    D
        RET  NZ
        LD    A, L
        CP    E
        RET

; ---------------------------------------------------------------------------
; Инкремент HL с проверкой на достижение DE и прерывание
Iterate_HL_DE_Brk:          
        CALL  CheckBreakByKbrd ; Проверка прерывания
Iterate_HL_to_DE:           
        CALL  Compare_HL_DE ; Проверка достижения DE
        JP    NZ, Inc_HL    ; Продолжить если не достигли
loc_F9C5:                  
        INC   SP            ; Корректировка стека
        INC   SP
        RET
Inc_HL:                     
        INC   HL
        RET

; ---------------------------------------------------------------------------
; Проверка прерывания по клавише СТОП
CheckBreakByKbrd:           
        CALL  ReadKeyCode
        CP    3             ; Код клавиши СТОП (Ctrl+C)
        RET  NZ
        JP    SyntaxError   ; Прерывание выполнения

; ---------------------------------------------------------------------------
; Переход на новую строку с табуляцией
NextLineAndTab:             
        PUSH  HL
        LD    HL, NextLineAndTabStr ; "\r\n\x18\x18\x18"
        CALL  PrintString
        POP   HL
        RET

; ---------------------------------------------------------------------------
; Печать байта по адресу HL
PrintBytePtrHL:             
        LD    A, (HL)
PrintLowHexByte:            
        PUSH  BC
        CALL  PrintHexByte
        CALL  PrintBlank
        POP   BC
        RET

; ===========================================================================
; Реализация директив монитора
; ===========================================================================

; ---------------------------------------------------------------------------
; Чтение ПЗУ (директива R)
DirectiveReadROM:           
        LD    A, 90h       ; Конфигурация BB55
        OUT   (0A3h), A

ReadNextRomByte:            
        LD    A, L          ; Установка младшего адреса
        OUT   (0A1h), A
        LD    A, H          ; Установка старшего адреса
        OUT   (0A2h), A
        IN    A, (0A0h)     ; Чтение данных
        LD    (BC), A       ; Сохранение в память
        INC   BC
        CALL  Iterate_HL_to_DE ; Переход к следующему адресу
        JP    ReadNextRomByte

; ---------------------------------------------------------------------------
; Получение/установка свободной памяти (директива A)
GetFreeMemAddr:             
        LD    HL, (FreeMemAddr)
        RET

SetFreeMemAddr:             
        LD    (FreeMemAddr), HL
        RET

; ---------------------------------------------------------------------------
; Установка обработчика (директива H)
DirectiveHookAdr:           
        LD    (HookAddress), HL
        RET

; ---------------------------------------------------------------------------
; Дамп памяти (директива D)
DirectiveDump:              
        CALL  LineFeed      ; Новая строка
        CALL  PrintHexWord  ; Печать адреса

        PUSH  HL
        LD    A, L          ; Вычисление отступа
        AND   0Fh
        LD    C, A
        RRA
        ADD   A, C
        ADD   A, C
        ADD   A, 5
        LD    B, A
        CALL  sub_FA5A      ; Выравнивание позиции

loc_FA1A:                  
        LD    A, (HL)       ; Печать HEX-дампа
        CALL  PrintHexByte
        CALL  Compare_HL_DE ; Проверка конца диапазона
        INC   HL
        JP    Z, loc_FA32   ; Переход к ASCII-дампу

        LD    A, L
        AND   0Fh
        PUSH  AF
        AND   1
        CALL  Z, PrintBlank ; Пробел после каждого второго байта

        POP   AF
        JP    NZ, loc_FA1A

loc_FA32:                  
        POP   HL            ; Восстановление начального адреса
        LD    A, L
        AND   0Fh
        ADD   A, 2Eh        ; Вычисление позиции для ASCII
        LD    B, A
        CALL  sub_FA5A      ; Выравнивание

loc_FA3C:                  
        LD    A, (HL)       ; Печать ASCII-символа
        CP    7Fh
        JP    NC, loc_FA47  ; Замена непечатных символов

        CP    20h
        JP    NC, loc_FA49

loc_FA47:                  
        LD    A, 2Eh        ; Замена на точку
loc_FA49:                  
        CALL  PrintCharfromA
        CALL  Compare_HL_DE ; Проверка конца диапазона
        RET  Z
        INC   HL
        LD    A, L
        AND   0Fh
        JP    NZ, loc_FA3C  ; Продолжить строку

        JP    DirectiveDump ; Новая строка дампа

; ---------------------------------------------------------------------------
; Выравнивание позиции (B=требуемая позиция)
sub_FA5A:                   
        LD    A, (CursorAddress)
        AND   3Fh
        CP    B
        RET  NC             ; Возврат если достигнута позиция
        CALL  PrintBlank    ; Печать пробела
        JP    sub_FA5A

; ---------------------------------------------------------------------------
; Печать пробела
PrintBlank:                 
        LD    A, ' '
        JP    PrintCharfromA

; ---------------------------------------------------------------------------
; Сравнение областей (директива C)
DirectiveCompare:           
        LD    A, (BC)       ; Сравнение байтов
        CP    (HL)
        JP    Z, NoDifference ; Совпадают

        CALL  PrintNextLnHexWord ; Печать адреса различия
        CALL  PrintBytePtrHL ; Печать байта из HL
        LD    A, (BC)       ; Печать байта из BC
        CALL  PrintLowHexByte

NoDifference:               
        INC   BC            ; Следующий байт
        CALL  Iterate_HL_DE_Brk ; Инкремент HL с проверкой прерывания
        JP    DirectiveCompare

; ---------------------------------------------------------------------------
; Заполнение памяти (директива F)
DirectiveFill:              
        LD    (HL), C       ; Запись байта
        CALL  Iterate_HL_to_DE ; Переход к следующему адресу
        JP    DirectiveFill

; ---------------------------------------------------------------------------
; Поиск байта (директива S)
DirectiveSearch:            
        LD    A, C          ; Сравнение с искомым байтом
        CP    (HL)
        CALL  Z, PrintNextLnHexWord ; Печать адреса совпадения
        CALL  Iterate_HL_DE_Brk ; Переход к следующему адресу
        JP    DirectiveSearch

; ---------------------------------------------------------------------------
; Поиск слова (директива W)
DirectiveSearchWrd:         
        LD    A, (HL)       ; Сравнение младшего байта
        CP    C
        JP    NZ, loc_FAA0

        INC   HL            ; Сравнение старшего байта
        LD    A, (HL)
        CP    B
        DEC   HL
        CALL  Z, PrintNextLnHexWord ; Печать адреса совпадения

loc_FAA0:                  
        CALL  Iterate_HL_DE_Brk ; Переход к следующему адресу
        JP    DirectiveSearchWrd

; ---------------------------------------------------------------------------
; Копирование памяти (директива T)
DirectiveCopy:              
        LD    A, (HL)       ; Чтение байта-источника
        LD    (BC), A       ; Запись в приемник
        INC   BC            ; Инкремент приемника
        CALL  Iterate_HL_to_DE ; Инкремент источника
        JP    DirectiveCopy

; ---------------------------------------------------------------------------
; Модификация памяти (директива M)
DirectiveModify:            
        CALL  PrintNextLnHexWord ; Печать адреса
        CALL  PrintBytePtrHL ; Печать текущего байта
        PUSH  HL            ; Сохранение адреса
        CALL  InputDirective ; Ввод нового значения
        POP   HL
        JP    NC, loc_FAC4  ; Пропуск если ввод пустой

        PUSH  HL
        CALL  sub_F980      ; Разбор HEX-числа
        LD    A, L          ; Младший байт результата
        POP   HL
        LD    (HL), A       ; Запись нового значения

loc_FAC4:                  
        INC   HL            ; Следующий адрес
        JP    DirectiveModify

; ---------------------------------------------------------------------------
; Запуск программы (директива G)
DirectiveRun:               
        CALL  Compare_HL_DE
        JP    Z, PlainRun   ; Без точки останова

        EX    DE, HL        ; Установка точки останова
        LD    (RST6_RUN_Var1), HL
        LD    A, (HL)
        LD    (RST6_RUN_Var2), A
        LD    (HL), 0F7h    ; Код инструкции RST 6
        LD    A, 0C3h       ; Код инструкции JMP
        LD    (30h), A
        LD    HL, RST6_handler
        LD    (31h), HL

PlainRun:                  
        LD    SP, 0F766h    ; Восстановление регистров
        POP   BC
        POP   DE
        POP   HL
        POP   AF
        LD    SP, HL        ; Восстановление SP
        LD    HL, (RST6_VAR1)
        JP    JMPcommand    ; Переход по адресу

; ---------------------------------------------------------------------------
; Обработчик RST 6 (точка останова)
RST6_handler:               
        LD    (RST6_VAR1), HL ; Сохранение HL
        PUSH  AF
        POP   HL            ; Сохранение AF в HL
        LD    (RST6_VAR2), HL
        POP   HL            ; Адрес возврата
        DEC   HL            ; Корректировка (адрес команды после RST6)
        LD    (RST6_VAR3), HL
        LD    HL, 0
        ADD   HL, SP        ; Текущий SP
        LD    SP, RST6_VAR2 ; Временный стек
        PUSH  HL            ; Сохранение SP
        PUSH  DE            ; Сохранение регистров
        PUSH  BC
        LD    SP, 0F800h    ; Восстановление системного стека
        LD    HL, (RST6_VAR3) ; Адрес останова
        EX    DE, HL
        LD    HL, (RST6_RUN_Var1) ; Адрес точки останова
        CALL  Compare_HL_DE
        JP    NZ, DirectiveRegisters ; Показ регистров если не совпадает

        ; Восстановление оригинальной команды
        LD    A, (RST6_RUN_Var2)
        LD    (HL), A

; ---------------------------------------------------------------------------
; Отображение регистров (директива X)
DirectiveRegisters:         
        LD    HL, RegistersListStr ; "\r\nPC-\r\nHL-\r\nBC-\r\nDE-\r\nSP-\r\nAF-\x19\x19\x19\x19\x19\x19"
        CALL  PrintString

        LD    HL, RST6_VAR3 ; Начало блока регистров
        LD    B, 6          ; Количество регистровых пар

loc_FB27:                  
        LD    E, (HL)       ; Чтение младшего байта
        INC   HL
        LD    D, (HL)       ; Чтение старшего байта
        PUSH  BC
        PUSH  HL
        EX    DE, HL
        CALL  PrintNextLnHexWord ; Печать значения

        CALL  InputDirective ; Ввод нового значения
        JP    NC, loc_FB3F  ; Пропуск если ввод пустой

        CALL  sub_F980      ; Разбор HEX-числа
        POP   DE
        PUSH  DE
        EX    DE, HL
        LD    (HL), D       ; Запись старшего байта
        DEC   HL
        LD    (HL), E       ; Запись младшего байта

loc_FB3F:                  
        POP   HL
        POP   BC
        DEC   B             ; Следующий регистр
        INC   HL
        JP    NZ, loc_FB27

        JP    RK86WarmReset ; Возврат в монитор

; ---------------------------------------------------------------------------
; Получение позиции курсора
GetCursorPos:               
        PUSH  AF
        LD    HL, (CursorAddress)
        LD    A, H          ; Вычисление Y-позиции
        AND   7
        LD    H, A
        LD    A, L          ; Вычисление X-позиции
        AND   3Fh
        ADD   A, 8
        ADD   HL, HL        ; Преобразование в экранные координаты
        ADD   HL, HL
        INC   H
        INC   H
        INC   H
        LD    L, A
        POP   AF
        RET

; ---------------------------------------------------------------------------
; Чтение видеопамяти (HL=адрес)
ReadVideoRAM:               
        PUSH  HL
        LD    HL, (CursorAddress)
        LD    A, (HL)       ; Чтение символа
        POP   HL
        RET

; ---------------------------------------------------------------------------
; Калибровка магнитофона (директива H)
DirectiveTapeConst:         
        CALL  NextLineAndTab
        LD    HL, 0FF80h    ; Инициализация счетчика
        LD    B, 7Bh        ; Количество измерений
        IN    A, (1)        ; Первое чтение
        LD    C, A

loc_FB70:                  
        IN    A, (1)        ; Ожидание изменения сигнала
        CP    C
        JP    Z, loc_FB70

loc_FB76:                  
        LD    C, A
loc_FB77:                  
        INC   HL            ; Инкремент счетчика длительности
        IN    A, (1)
        CP    C
        JP    Z, loc_FB77

        DEC   B             ; Следующее измерение
        JP    NZ, loc_FB76

        ADD   HL, HL        ; Расчет константы
        LD    A, H
        ADD   HL, HL
        ADD   A, H
        LD    L, A
        JP    PrintHexWord  ; Печать результата

; ---------------------------------------------------------------------------
; Чтение с магнитофона (директива I)
DirectiveTapeInp:           
        LD    A, (byte_F77B)
        OR    A
        JP    Z, loc_FB95

        LD    A, E          ; Установка новой константы
        LD    (TapeReadConst), A

loc_FB95:                  
        CALL  TapeReadBlock ; Чтение блока
        CALL  PrintNextLnHexWord ; Печать адреса начала
        EX    DE, HL
        CALL  PrintNextLnHexWord ; Печать адреса конца
        EX    DE, HL
        PUSH  BC
        CALL  CalcChecksum  ; Расчет контрольной суммы
        LD    H, B
        LD    L, C
        CALL  PrintNextLnHexWord ; Печать рассчитанной суммы
        POP   DE
        CALL  Compare_HL_DE ; Сравнение с прочитанной
        RET  Z              ; Возврат если совпадает

        EX    DE, HL
        CALL  PrintNextLnHexWord ; Печать ошибочной суммы
SyntaxError:                
        LD    A, '?'        ; Вывод ошибки
        CALL  PrintCharfromA
        JP    ProcessDirective ; Возврат в монитор

; ---------------------------------------------------------------------------
; Чтение блока с магнитофона
TapeReadBlock:              
        LD    A, 0FFh       ; Чтение заголовка
        CALL  sub_FBDA

        PUSH  HL            ; Сохранение адреса
        ADD   HL, BC        ; Расчет конечного адреса
        EX    DE, HL
        CALL  sub_FBD8       ; Чтение длины блока

        POP   HL            ; Восстановление адреса
        ADD   HL, BC        ; Расчет нового конца
        EX    DE, HL
        IN    A, (5)        ; Проверка флага ошибки
        AND   4
        RET  Z              ; Возврат если нет ошибки

        PUSH  HL            ; Чтение блока с обработкой ошибки
        CALL  sub_FBE5

        LD    A, 0FFh       ; Повторное чтение заголовка
        CALL  sub_FBDA

        POP   HL            ; Повторное чтение данных
        RET

; ---------------------------------------------------------------------------
; Чтение двухбайтового параметра
sub_FBD8:                   
        LD    A, 8
sub_FBDA:                   
        CALL  TapeReadByte  ; Чтение младшего байта
        LD    B, A
        LD    A, 8          ; Чтение старшего байта
        CALL  TapeReadByte
        LD    C, A
        RET

; ---------------------------------------------------------------------------
; Чтение блока данных
sub_FBE5:                   
        LD    A, 8          ; Количество битов
        CALL  TapeReadByte  ; Чтение байта
        LD    (HL), A       ; Сохранение
        CALL  Iterate_HL_to_DE ; Следующий адрес
        JP    sub_FBE5

; ---------------------------------------------------------------------------
; Расчет контрольной суммы (HL=начало, DE=конец)
CalcChecksum:               
        LD    BC, 0         ; Инициализация суммы

loc_FBF4:                  
        LD    A, (HL)       ; Суммирование байтов
        ADD   A, C
        LD    C, A
        PUSH  AF
        CALL  Compare_HL_DE ; Проверка конца блока
        JP    Z, loc_F9C5   ; Возврат с очисткой стека

        POP   AF
        LD    A, B
        ADC   A, (HL)          ; Суммирование с переносом
        LD    B, A
        CALL  Iterate_HL_to_DE ; Следующий адрес
        JP    loc_FBF4

; ---------------------------------------------------------------------------
; Запись на магнитофон (директива O)
DirectiveTapeOut:           
        LD    A, C          ; Проверка константы
        OR    A
        JP    Z, loc_FC10

        LD    (TapeWriteConst), A ; Установка новой константы

loc_FC10:                  
        PUSH  HL
        CALL  CalcChecksum  ; Расчет контрольной суммы
        POP   HL
        CALL  PrintNextLnHexWord ; Печать адреса начала
        EX    DE, HL
        CALL  PrintNextLnHexWord ; Печать адреса конца
        EX    DE, HL
        PUSH  HL
        LD    H, B
        LD    L, C
        CALL  PrintNextLnHexWord ; Печать контрольной суммы
        POP   HL

; ---------------------------------------------------------------------------
; Запись блока на магнитофон
TapeWriteBlock:             
        PUSH  BC            ; Сохранение контрольной суммы
        LD    BC, 0         ; Формирование преамбулы

loc_FC28:                  
        CALL  TapeWriteByte ; Запись нулевых байтов
        DEC   B
        EX    (SP), HL      ; Задержка
        EX    (SP), HL
        JP    NZ, loc_FC28

        LD    C, 0E6h       ; Маркер начала данных
        CALL  TapeWriteByte
        CALL  sub_FC6C      ; Запись адреса начала

        EX    DE, HL
        CALL  sub_FC6C      ; Запись адреса конца
        EX    DE, HL
        CALL  sub_FC62      ; Запись данных

        LD    HL, 0         ; Формирование пост-амбулы
        CALL  sub_FC6C
        LD    C, 0E6h       ; Маркер конца данных
        CALL  TapeWriteByte

        POP   HL            ; Запись контрольной суммы
        CALL  sub_FC6C
        RET

; ---------------------------------------------------------------------------
; Печать адреса с новой строки
PrintNextLnHexWord:         
        PUSH  BC
        CALL  NextLineAndTab
        CALL  PrintHexWord
        POP   BC
        RET

; ---------------------------------------------------------------------------
; Печать слова в HEX (HL=слово)
PrintHexWord:               
        LD    A, H          ; Печать старшего байта
        CALL  PrintHexByte
        LD    A, L          ; Печать младшего байта
        JP    PrintLowHexByte

; ---------------------------------------------------------------------------
; Запись блока данных на ленту
sub_FC62:                   
        LD    C, (HL)       ; Чтение байта
        CALL  TapeWriteByte ; Запись
        CALL  Iterate_HL_to_DE ; Следующий адрес
        JP    sub_FC62

; ---------------------------------------------------------------------------
; Запись слова на ленту (HL=слово)
sub_FC6C:                   
        LD    C, H          ; Запись старшего байта
        CALL  TapeWriteByte
        LD    C, L          ; Запись младшего байта
        JP    TapeWriteByte

; ===========================================================================
; Работа с магнитофоном
; ===========================================================================

; ---------------------------------------------------------------------------
; Чтение байта с магнитофона (A=количество битов)
TapeReadByte:               
        PUSH  HL
        PUSH  BC
        PUSH  DE
        LD    D, A          ; Сохранение счетчика битов

loc_FC78:                  
        LD    C, 0          ; Очистка принимаемого байта
        IN    A, (1)        ; Чтение начального уровня
        AND   1
        LD    E, A          ; Сохранение уровня

loc_FC7F:                  
        LD    A, C          ; Подготовка к приему бита
        AND   7Fh
        RLCA
        LD    C, A
        LD    H, 0          ; Счетчик таймаута

loc_FC86:                  
        DEC   H             ; Ожидание изменения сигнала
        JP    Z, loc_FCD2   ; Таймаут

        IN    A, (1)
        AND   1
        CP    E             ; Сравнение с предыдущим уровнем
        JP    Z, loc_FC86   ; Ожидание изменения

        OR    C             ; Добавление бита в байт
        LD    C, A
        DEC   D             ; Уменьшение счетчика битов
        LD    A, (TapeReadConst) ; Загрузка константы ожидания
        JP    NZ, loc_FC9D  ; Корректировка для последнего бита

        SUB   12h           ; Уменьшение задержки

loc_FC9D:                  
        LD    B, A
loc_FC9E:                  
        DEC   B             ; Задержка
        JP    NZ, loc_FC9E

        INC   D             ; Восстановление счетчика (псевдо-инкремент)
        IN    A, (1)        ; Обновление текущего уровня
        AND   1
        LD    E, A
        LD    A, D
        OR    A
        JP    P, loc_FCC6   ; Проверка на завершение

        ; Обработка служебных байтов
        LD    A, C
        CP    0E6h          ; Маркер начала данных
        JP    NZ, loc_FCBA

        XOR   A             ; Установка флага данных
        LD    (TapeReadVAR), A
        JP    loc_FCC4

loc_FCBA:                  
        CP    19h           ; Маркер конца данных
        JP    NZ, loc_FC7F

        LD    A, 0FFh       ; Установка флага конца
        LD    (TapeReadVAR), A

loc_FCC4:                  
        LD    D, 9          ; Установка счетчика битов

loc_FCC6:                  
        DEC   D
        JP    NZ, loc_FC7F  ; Прием следующего бита

        ; Проверка контрольной суммы
        LD    A, (TapeReadVAR)
        XOR   C             ; Сравнение с ожидаемым маркером
        POP   DE
        POP   BC
        POP   HL
        RET

loc_FCD2:                  
        LD    A, D          ; Проверка таймаута
        OR    A
        JP    P, SyntaxError ; Ошибка если в процессе приема

        CALL  CheckBreakByKbrd ; Проверка прерывания
        JP    loc_FC78      ; Повтор

; ---------------------------------------------------------------------------
; Запись байта на магнитофон (C=байт)
TapeWriteByte:              
        PUSH  BC
        PUSH  DE
        PUSH  AF
        LD    D, 8          ; Счетчик битов

loc_FCE2:                  
        LD    A, C          ; Подготовка бита
        RLCA
        LD    C, A
        LD    A, 1          ; Формирование выходного бита
        XOR   C
        OUT   (1), A        ; Запись бита
        LD    A, (TapeWriteConst) ; Задержка
        LD    B, A

loc_FCEE:                  
        DEC   B
        JP    NZ, loc_FCEE

        LD    A, 0          ; Возврат к базовому уровню
        XOR   C
        OUT   (1), A
        DEC   D             ; Корректировка задержки для последнего бита
        LD    A, (TapeWriteConst)
        JP    NZ, loc_FD00

        SUB   0Eh

loc_FD00:                  
        LD    B, A
loc_FD01:                  
        DEC   B             ; Задержка
        JP    NZ, loc_FD01

        INC   D             ; Псевдо-инкремент счетчика
        DEC   D             ; Проверка завершения
        JP    NZ, loc_FCE2  ; Следующий бит

        POP   AF
        POP   DE
        POP   BC
        RET

; ===========================================================================
; Функции ввода/вывода
; ===========================================================================

; ---------------------------------------------------------------------------
; Печать байта в HEX (A=байт)
PrintHexByte:               
        PUSH  AF            ; Сохранение байта
        RRCA                 ; Преобразование старшей тетрады
        RRCA
        RRCA
        RRCA
        CALL  sub_FD17      ; Печать тетрады
        POP   AF            ; Печать младшей тетрады

sub_FD17:                   
        AND   0Fh           ; Изоляция тетрады
        CP    0Ah
        JP    M, loc_FD20   ; Цифра 0-9

        ADD   A, 7          ; Коррекция для A-F

loc_FD20:                  
        ADD   A, 30h        ; Преобразование в ASCII

; ---------------------------------------------------------------------------
; Печать символа из регистра A
PrintCharfromA:             
        LD    C, A

; ---------------------------------------------------------------------------
; Печать символа из регистра C (основная функция вывода)
PrintCharFromC:             
        PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL
        CALL  GetKeyboardStatus ; Проверка клавиатуры (результат не используется)

        ; Скрытие курсора
        LD    B, 0
        CALL  ShowHideCursor

        LD    HL, (CursorAddress)
        LD    A, (EscSequenceState)
        DEC   A
        JP    M, NotInEscSequence ; Обработка если не в ESC-последовательности

        JP    Z, CheckIf59escCode ; Обработка после ESC

        DEC   A
        JP    NZ, ProcessEsc59ArgX ; Обработка второго аргумента ESC Y

        ; Обработка аргумента Y для ESC Y
        LD    A, C
        SUB   20h           ; Коррекция Y
        JP    P, CheckUpBound

        XOR   A             ; Ограничение снизу Y=0
        JP    ConvertYtoVideoAddr

CheckUpBound:               
        CP    ScreenHeight  ; Ограничение сверху
        JP    M, ConvertYtoVideoAddr

        LD    A, ScreenHeight-1

ConvertYtoVideoAddr:        
        RRCA                 ; Преобразование Y в адрес видеопамяти
        RRCA
        LD    C, A
        AND   0C0h
        LD    B, A
        LD    A, L
        AND   3Fh
        OR    B
        LD    L, A
        LD    A, C
        AND   7
        LD    B, A
        LD    A, H
        AND   0F8h
        OR    B
        LD    H, A
        LD    A, 3          ; Ожидание второго аргумента X
;        JP    UpdateEscCurPsState

; ---------------------------------------------------------------------------
UpdateEscCurPsState:
        LD    (EscSequenceState), A

; ---------------------------------------------------------------------------
; Обновление позиции курсора
UpdCurPosAndReturn:         
        LD    (CursorAddress), HL

; ---------------------------------------------------------------------------
; Отображение курсора
ShowCursorAndReturn:        
        LD    B, 0FFh       ; Показать курсор
        CALL  ShowHideCursor

        POP   HL
        POP   DE
        POP   BC
        POP   AF
        RET

; ---------------------------------------------------------------------------
; Управление отображением курсора (B=00-скрыть, FF-показать)
ShowHideCursor:             
        LD    A, (CursorVisible)
        OR    A
        RET  Z              ; Выход если курсор скрыт
        LD    HL, (CursorAddress)
        LD    DE, 0F801h    ; Смещение в буфер курсора
        ADD   HL, DE
        LD    (HL), B       ; Установка флага видимости
        RET

; ---------------------------------------------------------------------------
; Обработка первого аргумента ESC Y
ProcessEsc59ArgX:           
        LD    A, C
        SUB   20h           ; Коррекция X
        JP    P, CheckRightBound

        XOR   A             ; Ограничение слева X=0
        JP    ConvertXToVideoAddr

CheckRightBound:            
        CP    ScreenWidth   ; Ограничение справа
        JP    M, ConvertXToVideoAddr

        LD    A, ScreenWidth-1

ConvertXToVideoAddr:        
        LD    B, A
        LD    A, L
        AND   0C0h
        OR    B
        LD    L, A

; ---------------------------------------------------------------------------
; Завершение ESC-последовательности
EndEscSequence:             
        XOR   A             ; Сброс состояния ESC
        JP    UpdateEscCurPsState

; ---------------------------------------------------------------------------
; Проверка кода после ESC
CheckIf59escCode:           
        LD    A, C
        CP    59h           ; ESC Y (установка позиции)?
        JP    NZ, CheckIf61escCode

        LD    A, 2          ; Ожидание аргумента Y
        JP    UpdateEscCurPsState

CheckIf61escCode:           
        CP    61h           ; ESC a (скрыть курсор)?
        JP    NZ, CheckIf62escCode

        XOR   A             ; Установка флага скрытия
        JP    UpdateEsc6162

CheckIf62escCode:           
        CP    62h           ; ESC b (показать курсор)?
        JP    NZ, EndEscSequence

UpdateEsc6162:              
        LD    (CursorVisible), A
        JP    EndEscSequence

; ---------------------------------------------------------------------------
; Обработка обычных символов
NotInEscSequence:           
        IN    A, (5)        ; Проверка клавиш
        AND   6             ; Маска клавиш "'"+CC"
        JP    Z, NotInEscSequence ; Ожидание отпускания

        LD    A, 10h        ; Проверка на ESC-код 10h
        CP    C
        LD    A, (HookActive)
        JP    NZ, GoHookAndPrint

        CPL                 ; Инверсия флага активности
        LD    (HookActive), A
        JP    UpdCurPosAndReturn

; ---------------------------------------------------------------------------
; Вызов обработчика и печать
GoHookAndPrint:             
        OR    A
        CALL  NZ, HookJmp   ; Вызов обработчика если активен

        LD    A, C          ; Проверка управляющих символов
        CP    1Fh
        JP    Z, DoClearScreen

        JP    M, ProcessEscCodes ; Обработка ESC-кодов

; ---------------------------------------------------------------------------
; Печать обычного символа
DoPrintChar:                
        LD    (HL), A       ; Запись символа в видеопамять
        INC   HL            ; Следующая позиция
        LD    A, H
        CP    SymbolBufEndHI ; Проверка конца экрана
        JP    M, UpdCurPosAndReturn

        CALL  LineFeed      ; Скроллинг экрана
        JP    ShowCursorAndReturn

; ---------------------------------------------------------------------------
; Очистка экрана (ESC 1Fh)
DoClearScreen:              
        LD    B, ' '        ; Символ пробела
        LD    A, 0F0h       ; Верхняя граница видеопамяти
        LD    HL, CursorBufferStart

ClearNextScrPos:            
        LD    (HL), B       ; Очистка буфера курсора
        INC   HL
        LD    (HL), B       ; Очистка буфера символов
        INC   HL
        CP    H             ; Проверка достижения конца
        JP    NZ, ClearNextScrPos

; ---------------------------------------------------------------------------
; Установка курсора в домашнюю позицию (ESC 0Ch)
DoCursorHome:               
        LD    HL, SymbolBufferStart
        JP    UpdCurPosAndReturn

; ---------------------------------------------------------------------------
; Обработка управляющих кодов
ProcessEscCodes:            
        CP    0Ch           ; Home
        JP    Z, DoCursorHome

        CP    0Dh           ; Return
        JP    Z, DoReturn

        CP    0Ah           ; LineFeed
        JP    Z, DoLineFeed

        CP    8             ; Left
        JP    Z, DoCursorLeft

        CP    18h           ; Right
        JP    Z, DoCursorRight

        CP    19h           ; Up
        JP    Z, DoCursorUp

        CP    7             ; Bell
        JP    Z, DoBeep

        CP    1Ah           ; Down
        JP    Z, DoCursorDown

        CP    1Bh           ; ESC
        JP    NZ, DoPrintChar

        ; Начало ESC-последовательности
        LD    A, 1          ; Установка состояния ESC
        JP    UpdateEscCurPsState

; ---------------------------------------------------------------------------
; Звуковой сигнал
DoBeep:                     
        LD    C, 80h        ; Длительность сигнала
        LD    E, 20h        ; Частота

WaweRepeat:                 
        LD    D, E          ; Сохранение частоты

DelayLoop1:                 
        LD    A, 0Fh        ; Включение звука
        OUT   (4), A
        DEC   E             ; Задержка
        JP    NZ, DelayLoop1

        LD    E, D          ; Восстановление частоты

DelayLoop2:                 
        LD    A, 0Eh        ; Выключение звука
        OUT   (4), A
        DEC   D             ; Задержка
        JP    NZ, DelayLoop2

        DEC   C             ; Следующий полупериод
        JP    NZ, WaweRepeat

        JP    ShowCursorAndReturn

; ---------------------------------------------------------------------------
; Возврат каретки
DoReturn:                   
        LD    A, L          ; Сброс X-координаты
        AND   0C0h
        LD    L, A
        JP    UpdCurPosAndReturn

; ---------------------------------------------------------------------------
; Курсор вправо
DoCursorRight:              
        INC   HL
CheckVertBoundary:          
        LD    A, H          ; Проверка границы экрана по Y
        AND   7
        OR    (SymbolBufferStart & 0FF00H) >> 8
        LD    H, A
        JP    UpdCurPosAndReturn

; ---------------------------------------------------------------------------
; Курсор влево
DoCursorLeft:               
        DEC   HL
        JP    CheckVertBoundary

; ---------------------------------------------------------------------------
; Перевод строки
DoLineFeed:                 
        LD    BC, ScreenWidth ; Смещение на строку вниз
        ADD   HL, BC
        LD    A, H
        CP    SymbolBufEndHI ; Проверка нижней границы
        JP    M, UpdCurPosAndReturn

        ; Скроллинг экрана вверх
        LD    HL, SymbolBufferStart
        LD    BC, SymbolBufferStart+ScreenWidth

ContinueScroll:             
        LD    A, (BC)       ; Чтение символа снизу
        LD    (HL), A       ; Запись на текущую позицию
        INC   HL
        INC   BC
        LD    A, (BC)
        LD    (HL), A
        INC   HL
        INC   BC
        LD    A, B          ; Проверка конца экрана
        CP    SymbolBufEndHI
        JP    M, ContinueScroll

        ; Очистка последней строки
        LD    A, SymbolBufEndHI
        LD    C, ' '

ClearLastLine:              
        LD    (HL), C       ; Очистка символа
        INC   HL
        LD    (HL), C       ; Очистка атрибута
        INC   HL
        CP    H             ; Проверка конца
        JP    NZ, ClearLastLine

        ; Установка курсора в начало последней строки
        LD    HL, (CursorAddress)
        LD    H, SymbolBufEndHI-1
        LD    A, L
        OR    0C0h          ; Сохранение X-позиции
        LD    L, A
        JP    UpdCurPosAndReturn

; ---------------------------------------------------------------------------
; Курсор вверх
DoCursorUp:                 
        LD    BC, -ScreenWidth ; Смещение на строку вверх
AddBXtoHL:                  
        ADD   HL, BC
        JP    CheckVertBoundary

; ---------------------------------------------------------------------------
; Курсор вниз
DoCursorDown:               
        LD    BC, ScreenWidth
        JP    AddBXtoHL

; ---------------------------------------------------------------------------
; Перевод строки (CR+LF)
LineFeed:                   
        LD    C, 0Dh        ; Возврат каретки
        CALL  PrintCharFromC
        LD    C, 0Ah        ; Перевод строки
        JP    PrintCharFromC

; ---------------------------------------------------------------------------
; Проверка состояния клавиатуры
GetKeyboardStatus:          
        XOR   A             ; Сброс клавиатуры
        OUT   (7), A
        IN    A, (6)        ; Чтение состояния
        AND   7Fh           ; Игнорирование старшего бита
        CP    7Fh           ; Проверка нажатия
        JP    NZ, KeyIsPressed

        XOR   A             ; Клавиша не нажата
        RET

KeyIsPressed:               
        LD    A, 0FFh       ; Клавиша нажата
        RET

; ---------------------------------------------------------------------------
; Ввод символа с клавиатуры
InputSymbol:                
        PUSH  HL
        LD    HL, (LastKeyStatus) ; H=последняя клавиша, L=счетчик автоповтора
        CALL  WaitKeyStateChange ; Ожидание изменения состояния

        LD    L, 20h        ; Задержка перед автоповтором
        JP    Z, Autorepeat  ; Если клавиша удерживается

loc_FED4:                  
        LD    L, 2          ; Задержка перед первым повтором
        CALL  WaitKeyStateChange

        JP    NZ, loc_FED4  ; Ожидание отпускания

        CP    80h           ; Проверка на управляющий символ
        JP    NC, loc_FED4  ; Игнорирование

        LD    L, 80h        ; Задержка автоповтора

Autorepeat:                 
        LD    (LastKeyStatus), HL ; Сохранение состояния
        POP   HL
        RET

; ---------------------------------------------------------------------------
; Ожидание изменения состояния клавиатуры
WaitKeyStateChange:         
        CALL  ReadKeyCode   ; Чтение текущей клавиши
        CP    H             ; Сравнение с предыдущей
        JP    NZ, KeyStateChanged ; Изменилось

        PUSH  AF            ; Короткая задержка
        XOR   A
DoDelay:                    
        EX    DE, HL
        EX    DE, HL
        DEC   A
        JP    NZ, DoDelay

        POP   AF
        DEC   L             ; Уменьшение счетчика
        JP    NZ, WaitKeyStateChange

; ---------------------------------------------------------------------------
; Изменение состояния клавиши
KeyStateChanged:            
        LD    H, A          ; Сохранение новой клавиши
        RET

; ---------------------------------------------------------------------------
; Чтение кода клавиши
ReadKeyCode:                
        PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    BC, 0FEh      ; Начальная маска строк
        LD    D, 8          ; Количество строк

loc_FF06:                  
        LD    A, C          ; Активация строки
        OUT   (7), A
        RLCA                 ; Сдвиг маски
        LD    C, A
        IN    A, (6)        ; Чтение столбцов
        AND   7Fh           ; Игнорирование старшего бита
        CP    7Fh           ; Проверка нажатия
        JP    NZ, loc_FF28  ; Нажатие обнаружено

        ; Переход к следующей строке
        LD    A, B
        ADD   A, 7          ; Смещение кода
        LD    B, A
        DEC   D
        JP    NZ, loc_FF06

        ; Проверка клавиши СТОП
        IN    A, (5)
        RRA                 ; Проверка бита СТОП
        LD    A, 0FFh
        JP    C, ReturnFromReadKey ; Нажата СТОП

        DEC   A             ; Код СТОП = FEh
        JP    ReturnFromReadKey

loc_FF28:                  
        ; Определение нажатой клавиши в строке
        RRA                 ; Проверка бита
        JP    NC, loc_FF30  ; Переход если бит=0
        INC   B             ; Следующий столбец
        JP    loc_FF28

loc_FF30:                  
        LD    A, B          ; Преобразование в ASCII
        CP    30h           ; Проверка диапазона
        JP    NC, GenerateEscCode ; Управляющие клавиши

        ADD   A, 30h        ; Коррекция цифр
        CP    3Ch           ; Проверка на буквы
        JP    C, loc_FF44

        CP    40h
        JP    NC, loc_FF44
        AND   2Fh           ; Коррекция A-Z

loc_FF44:                  
        CP    5Fh           ; Проверка на символ '_'
        JP    NZ, loc_FF4B
        LD    A, 7Fh        ; Замена на DEL

loc_FF4B:                  
        LD    C, A          ; Сохранение кода
        IN    A, (5)        ; Проверка модификаторов
        AND   7
        CP    7
        LD    B, A
        LD    A, C
        JP    Z, ReturnFromReadKey ; Без модификаторов

        LD    A, B
        RRA
        RRA
        JP    NC, loc_FF68  ; Обработка SHIFT

        RRA
        JP    NC, loc_FF6E  ; Обработка CTRL

        LD    A, C
        OR    20h           ; Перевод в нижний регистр

;        JP    ReturnFromReadKey
; ---------------------------------------------------------------------------
; Возврат из чтения клавиши
ReturnFromReadKey:          
        POP   HL
        POP   DE
        POP   BC
        RET

loc_FF68:                  
        LD    A, C
        AND   1Fh           ; Управляющие символы
        JP    ReturnFromReadKey

loc_FF6E:                  
        LD    A, C
        CP    7Fh           ; Замена DEL на '_'
        JP    NZ, loc_FF76
        LD    A, 5Fh

loc_FF76:                  
        CP    40h           ; Обработка букв под CTRL
        JP    NC, ReturnFromReadKey
        CP    30h
        JP    NC, loc_FF85
        OR    10h           ; Коррекция CTRL+0-9
        JP    ReturnFromReadKey

loc_FF85:                  
        AND   2Fh           ; Коррекция CTRL+A-Z
        JP    ReturnFromReadKey

; ---------------------------------------------------------------------------
; Генерация ESC-кодов для управляющих клавиш
GenerateEscCode:            
        LD    HL, ESCcodesMap
        SUB   30h           ; Индекс в таблице
        LD    C, A
        LD    B, 0
        ADD   HL, BC
        LD    A, (HL)       ; Загрузка ESC-кода
        JP    ReturnFromReadKey


; ===========================================================================
; Данные
; ===========================================================================

; Таблица ESC-кодов для управляющих клавиш
ESCcodesMap:    DB  20h     ; Space
        DB  18h             ; Right
        DB    8             ; Left
        DB  19h             ; Up
        DB  1Ah             ; Down
        DB  0Dh             ; Enter
        DB  1Fh             ; Clear
        DB  0Ch             ; Home

; Строковые константы
DirectivePrompt:DB 0Dh, 0Ah ; Приглашение ввода
        DB "-->"
        DB 0

NextLineAndTabStr:DB 0Dh, 0Ah, 18h, 18h, 18h, 0 ; Новая строка и табуляция

RegistersListStr:DB 0Dh, 0Ah ; Список регистров
        DB "PC-"
        DB 0Dh, 0Ah
        DB "HL-"
        DB 0Dh, 0Ah
        DB "BC-"
        DB 0Dh, 0Ah
        DB "DE-"
        DB 0Dh, 0Ah
        DB "SP-"
        DB 0Dh, 0Ah
        DB "AF-"
        DB 19h, 19h, 19h, 19h, 19h, 19h, 0

BackspaceStr:   DB 8        ; Строка Backspace
        DB " "
        DB 8, 0

WelcomeMsg:     DB 1Fh, 0Ah ; Приветственное сообщение
        DB "m/80k "
        DB 0

; Заглушка обработчика
DummyHook:      DB 0C9h     ; RET

        DB 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
        DB 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
        DB 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
        DB 0FFh,0FFh,0FFh,0FFh

; Конец ROM
        END
