

;  МОНИТОР МИКРО-80
;  ================

        CPU		8080
		
		Z80SYNTAX	EXCLUSIVE
        
		
        ORG     0f800H

RABADR  EQU     0F800H

EK_ADR  EQU     0F75AH
YF765   EQU     0F765H
STACK   EQU     0F7FFH
COMBUF  EQU     0F77BH
P_JMP   EQU     0F750H          ; здесь JMP по G
PAR_HL  EQU     0F751H
PAR_DE  EQU     0F753H
PAR_BC  EQU     0F755H

; ----------------------------------------------


AF800:  JP      START
        JP      CONIN
        JP      LDBYTE
        JP      COUT_C
        JP      WRBYTE
        JP      COUT_C
        JP      STATUS
        JP      HEX_A
        JP      MSSG

; ----------------------------------------------

START:  LD      HL,0F7C0H
        LD      (YF765),HL

        LD      SP,STACK

        LD      A,1FH
        CALL    COUT_A

WARMST: LD      A,8BH
        OUT     (4),A

        LD      SP,STACK

        LD      HL,PROMPT
        CALL    MSSG

        CALL    GETLIN

        LD      HL,WARMST
        PUSH    HL

AF83D:  LD      HL,COMBUF
        LD      B,(HL)
        LD      HL,TABLE
CMDLOO: LD      A,(HL)
        AND     A               ; OR A
        JP      Z,ERROR
        CP      B
        JP      Z,FOUND
        INC     HL
        INC     HL
        INC     HL
        JP      CMDLOO

; ----------------------------------------------

FOUND:  INC     HL              ; 7 bytes
        LD      SP,HL
        POP     HL
        LD      SP,0F7FDH
        JP      (HL)

		if	0
.comment \

FOUND:  INC     DE              ; 5 bytes
        LD      L,(DE)
        INC     DE
        LD      H,(DE)
        JP      (HL)
\
		endif
; ----------------------------------------------

GETLIN: LD      HL,COMBUF
GTLLOO: CALL    CONIN
        CP      8
        JP      Z,ZABOJ
        CALL    NZ,COUT_A
        LD      (HL),A
        CP      13
        JP      Z,GLDONE
        LD      A, (COMBUF+31) & 0ffh
        CP      L
        INC     HL
        JP      NZ,GTLLOO
ERROR:  LD      A,'?'
        CALL    COUT_A
        JP      WARMST

; ----------------------------------------------

GLDONE: LD      (HL),13
        RET

; ----------------------------------------------

ZABOJ:  CALL    BUFLFT
        JP      GTLLOO

; ----------------------------------------------

BUFLFT: LD      A, COMBUF & 0ffh
        CP      L
        RET     Z
        LD      A,8
        CALL    COUT_A
        DEC     HL
        RET

; ----------------------------------------------

AF891:  CALL    SPACE
        LD      HL,COMBUF
AF897:  LD      B,0
AF899:  CALL    CONIN
        CP      8
        JP      Z,AF8C5
        CALL    NZ,COUT_A
        LD      (HL),A
        CP      20H
        JP      Z,AF8BB
        CP      13
        JP      Z,POPAF
        LD      B,0FFH
        LD      A, (COMBUF+31) & 0ffh
        CP      L
        JP      Z,ERROR
        INC     HL
        JP      AF899

; ----------------------------------------------

AF8BB:  LD      (HL),13
        LD      A,B
        RLA
        LD      DE,COMBUF
        LD      B,0
        RET

; ----------------------------------------------

AF8C5:  CALL    BUFLFT
        JP      Z,AF897
        JP      AF899

; ----------------------------------------------

POPAF:  INC     SP
        INC     SP
        RET

; ----------------------------------------------

CR:     LD      HL,T_CR
MSSG:   LD      A,(HL)
        AND     A
        RET     Z
        CALL    COUT_A
        INC     HL
        JP      MSSG

; ----------------------------------------------

GETPRM: LD      HL,PAR_HL

        LD      B,6
        XOR     A
FILLOO: LD      (HL),A
        DEC     B
        JP      NZ,FILLOO

        LD      DE,0F77CH
        CALL    GET_HL

        LD      (PAR_HL),HL
        LD      (PAR_DE),HL
        RET     C

        CALL    GET_HL
        LD      (PAR_DE),HL

        PUSH    AF
        PUSH    DE
        EX      DE,HL
        LD      HL,(PAR_HL)
        EX      DE,HL
        CALL    CMPDH
        JP      C,ERROR
        POP     DE
        POP     AF
        RET     C

        CALL    GET_HL
        LD      (PAR_BC),HL
        RET     C

        JP      ERROR

; ----------------------------------------------

; Вводит в HL HEX-число из строки по (DE) до нажатия ВК

GET_HL: LD      HL,0
AF919:  LD      A,(DE)
        INC     DE
        CP      13
        JP      Z,RETCY1
        CP      ','
        RET     Z
        CP      20H
        JP      Z,AF919
        SUB     '0'
        JP      M,ERROR
        CP      10
        JP      M,AF93E
        CP      11H
        JP      M,ERROR
        CP      17H
        JP      P,ERROR
        SUB     7
AF93E:  LD      C,A
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        JP      C,ERROR
        ADD     HL,BC
        JP      AF919

; ----------------------------------------------

RETCY1: SCF
        RET

; ----------------------------------------------

AF94C:  LD      HL,(PAR_HL)
        LD      A,(HL)
HEX_A:  LD      B,A
        LD      A,B
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    NIBBLE
        LD      A,B
NIBBLE: AND     0FH
        CP      10
        JP      M,AF963
        ADD     A,7
AF963:  ADD     A,'0'
        JP      COUT_A

; ----------------------------------------------

AF968:  CALL    CR
PRPAR1: LD      HL,PAR_HL+1     ; HEX-вывод 1-го параметра и пробела
AF96E:  LD      A,(HL)
        CALL    HEX_A
        DEC     HL
        LD      A,(HL)          ; PAR_HL
        CALL    HEX_A
SPACE:  LD      A,20H
        JP      COUT_A

; ----------------------------------------------

AF97C:  PUSH    DE
        LD      HL,(PAR_HL)
        EX      DE,HL
        LD      HL,(PAR_DE)
        CALL    CMPDH
        POP     DE
        JP      Z,POPAF

        LD      HL,PAR_HL
AF98E:  INC     (HL)
        RET     NZ
        INC     HL
        INC     (HL)
        RET

; ----------------------------------------------

CMPDH:  LD      A,H
        CP      D
        RET     NZ
        LD      A,L
        CP      E
        RET

; ----------------------------------------------

DIR_X:  LD      HL,0F77CH
        LD      A,(HL)
        CP      13
        JP      Z,XVIEW
        CP      'S'
        JP      Z,AF9C8

        LD      DE,LETTERS
        CALL    AF9DE
        LD      HL,YF765
        INC     DE
        LD      A,(DE)
        LD      L,A
        PUSH    HL
        CALL    SPACE
        LD      A,(HL)
        CALL    HEX_A
        CALL    AF891
        JP      NC,WARMST

        CALL    GET_HL
        LD      A,L
        POP     HL
        LD      (HL),A
        RET

; ----------------------------------------------

AF9C8:  CALL    SPACE
        LD      HL,0F766H
        CALL    AF96E
        CALL    AF891
        JP      NC,WARMST
        CALL    GET_HL
        LD      (YF765),HL
        RET

; ----------------------------------------------

AF9DE:  LD      A,(DE)
        AND     A
        JP      Z,ERROR
        CP      (HL)
        RET     Z
        INC     DE
        INC     DE
        JP      AF9DE

; ----------------------------------------------

XVIEW:  LD      DE,LETTERS
        LD      B,8
        CALL    CR
AF9F2:  LD      A,(DE)
        LD      C,A
        INC     DE

        PUSH    BC
        CALL    C_TIRE
        LD      A,(DE)
        LD      HL,YF765        ; LD H,0F7H
        LD      L,A
        LD      A,(HL)
        CALL    HEX_A
        POP     BC

        INC     DE
        DEC     B
        JP      NZ,AF9F2

        LD      A,(DE)
        LD      C,A
        CALL    C_TIRE
        LD      HL,(YF765)
        LD      (PAR_HL),HL
        CALL    PRPAR1
        LD      C,'O'
        CALL    C_TIRE
        LD      HL,0F770H
        CALL    AF96E
        JP      CR

; ----------------------------------------------

C_TIRE: CALL    SPACE
        LD      A,C
        CALL    COUT_A
        LD      A,'-'
        JP      COUT_A

; ----------------------------------------------

R_SP    EQU     0F765H
R_AF    EQU     0F767H          ; 67 68
R_BC    EQU     0F769H          ; 69 6A
R_DE    EQU     0F76BH          ; 6C 6D
R_HL    EQU     0F76DH          ; 6D 6E

; второй байт - младший байт адреса F7xx
; где хранится содержимого регистра

LETTERS:
        DB    'A', (R_AF+1) & 0ffh  ; 68H
        DB    'B', (R_BC+1) & 0ffh  ; 6AH
        DB    'C', (R_BC) & 0ffh    ; 69H
        DB    'D', (R_DE+1) & 0ffh  ; 6CH
        DB    'E', (R_DE) & 0ffh    ; 6BH
        DB    'F', (R_AF) & 0ffh    ; 67H
        DB    'H', (R_HL+1) & 0ffh  ; 6EH
        DB    'L', (R_HL) & 0ffh    ; 6DH
        DB    'S', (R_SP) & 0ffh    ; 65H
        DB    0

TSTART: DB    10,'START-',0
T_DIR:  DB    10,'DIR. -',0

; ----------------------------------------------

DIR_B:  CALL    GETPRM
        CALL    SET_38
        LD      HL,(PAR_HL)
        LD      A,(HL)
        LD      (HL),0FFH
        LD      (0F772H),HL
        LD      (0F774H),A
        RET

; ----------------------------------------------

SET_38: LD      A,0C3H
        LD      (0038H),A
        LD      HL,BREAK
        LD      (0039H),HL
        RET

; ----------------------------------------------


BREAK:  LD      (R_HL),HL

        PUSH    AF
        LD      HL,4
        ADD     HL,SP
        LD      (YF765),HL
        POP     AF

        EX      (SP),HL
        DEC     HL
        EX      (SP),HL
        LD      SP,R_HL

        PUSH    DE
        PUSH    BC
        PUSH    AF

        LD      SP,STACK
        LD      HL,(YF765)
        DEC     HL
        LD      D,(HL)
        DEC     HL
        LD      E,(HL)
        LD      L,E
        LD      H,D
        LD      (0F76FH),HL

        LD      HL,(0F772H)
        CALL    CMPDH
        JP      Z,AFAB4

        LD      HL,(0F775H)
        CALL    CMPDH
        JP      Z,AFB24

        LD      HL,(0F778H)
        CALL    CMPDH
        JP      Z,AFB46

        JP      ERROR

; ----------------------------------------------

AFAB4:  LD      A,(0F774H)
        LD      (HL),A

        LD      HL,0FFFFH
        LD      (0F772H),HL

        JP      WARMST

; ----------------------------------------------

DIR_G:  CALL    GETPRM
        LD      A,(0F77CH)
        CP      13
        JP      NZ,AFAD2

        LD      HL,(0F76FH)
        LD      (PAR_HL),HL

AFAD2:  LD      A,0C3H
        LD      (P_JMP),A
        LD      SP,YF765
        POP     HL
        POP     AF
        POP     BC
        POP     DE
        LD      SP,HL
        LD      HL,(R_HL)
        JP      P_JMP

; ----------------------------------------------

DIR_P:  CALL    GETPRM
        CALL    SET_38

        LD      HL,(PAR_HL)
        LD      (0F775H),HL

        LD      A,(HL)
        LD      (HL),0FFH
        LD      (0F777H),A

        LD      HL,(PAR_DE)
        LD      (0F778H),HL

        LD      A,(HL)
        LD      (HL),0FFH
        LD      (0F77AH),A

        LD      A,(PAR_BC)
        LD      (0F771H),A

        LD      HL,TSTART
        CALL    MSSG

        LD      HL,0F77CH
        CALL    GTLLOO
        CALL    GETPRM

        LD      HL,T_DIR
        CALL    MSSG

        CALL    GETLIN
        JP      AFAD2

; ----------------------------------------------

AFB24:  LD      A,(0F777H)
        LD      (HL),A

        LD      HL,(0F778H)
        LD      A,0FFH
        CP      (HL)
        JP      Z,AFB37

        LD      B,(HL)
        LD      (HL),A
        LD      A,B
        LD      (0F77AH),A

AFB37:  CALL    XVIEW
        CALL    AF83D
        LD      HL,(0F76FH)
        LD      (PAR_HL),HL
        JP      AFAD2

; ----------------------------------------------

AFB46:  LD      A,(0F77AH)
        LD      (HL),A
        LD      HL,(0F775H)
        LD      A,0FFH
        CP      (HL)
        JP      Z,AFB37
        LD      B,(HL)
        LD      (HL),A
        LD      A,B
        LD      (0F777H),A
        LD      HL,0F771H
        DEC     (HL)
        JP      NZ,AFB37
        LD      A,(0F777H)
        LD      HL,(0F775H)
        LD      (HL),A
        JP      WARMST

; ----------------------------------------------

DIR_D:  CALL    GETPRM
        CALL    CR
AFB70:  CALL    AF968
AFB73:  CALL    SPACE
        CALL    AF94C
        CALL    AF97C
        LD      A,(PAR_HL)
        AND     0FH
        JP      Z,AFB70
        JP      AFB73

; ----------------------------------------------

DIR_C:  CALL    GETPRM
        LD      HL,(PAR_BC)
        EX      DE,HL
AFB8E:  LD      HL,(PAR_HL)
        LD      A,(DE)
        CP      (HL)
        JP      Z,AFBA6
        CALL    AF968
        CALL    SPACE
        CALL    AF94C
        CALL    SPACE
        LD      A,(DE)
        CALL    HEX_A
AFBA6:  INC     DE
        CALL    AF97C
        JP      AFB8E

; ----------------------------------------------

DIR_F:  CALL    GETPRM
        LD      A,(PAR_BC)
        LD      B,A
AFBB4:  LD      HL,(PAR_HL)
        LD      (HL),B
        CALL    AF97C
        JP      AFBB4

; ----------------------------------------------

DIR_S:  CALL    GETPRM
        LD      C,L
AFBC2:  LD      HL,(PAR_HL)
        LD      A,C
        CP      (HL)
        CALL    Z,AF968
        CALL    AF97C
        JP      AFBC2

; ----------------------------------------------

DIR_T:  CALL    GETPRM
        LD      HL,(PAR_BC)
        EX      DE,HL
AFBD7:  LD      HL,(PAR_HL)
        LD      A,(HL)
        LD      (DE),A
        INC     DE
        CALL    AF97C
        JP      AFBD7

; ----------------------------------------------

DIR_M:  CALL    GETPRM
AFBE6:  CALL    SPACE
        CALL    AF94C
        CALL    AF891
        JP      NC,AFBFA
        CALL    GET_HL
        LD      A,L
        LD      HL,(PAR_HL)
        LD      (HL),A
AFBFA:  LD      HL,PAR_HL
        CALL    AF98E
        CALL    AF968
        JP      AFBE6

; ----------------------------------------------

DIR_J:  CALL    GETPRM
        LD      HL,(PAR_HL)
        JP      (HL)

; ----------------------------------------------

DIR_A:  CALL    CR
        LD      A,(0F77CH)
        CALL    HEX_A
        JP      CR

; ----------------------------------------------

DIR_K:  CALL    CONIN
        CP      1
        JP      Z,WARMST
        CALL    COUT_A
        JP      DIR_K

; ----------------------------------------------

DIR_Q:  CALL    GETPRM
AFC2A:  LD      HL,(PAR_HL)
        LD      C,(HL)
        LD      A,55H
        LD      (HL),A
        CP      (HL)
        CALL    NZ,AFC43
        LD      A,0AAH
        LD      (HL),A
        CP      (HL)
        CALL    NZ,AFC43
        LD      (HL),C
        CALL    AF97C
        JP      AFC2A

; ----------------------------------------------

AFC43:  PUSH    AF
        CALL    AF968
        CALL    SPACE
        CALL    AF94C
        CALL    SPACE
        POP     AF
        CALL    HEX_A
        RET

; ----------------------------------------------

DIR_L:  CALL    GETPRM
        CALL    CR
AFC5B:  CALL    AF968
AFC5E:  CALL    SPACE
        LD      HL,(PAR_HL)
        LD      A,(HL)
        CP      20H
        JP      C,AFC72
        CP      80H
        JP      NC,AFC72
        JP      AFC74

; ----------------------------------------------

AFC72:  LD      A,'.'
AFC74:  CALL    COUT_A
        CALL    AF97C
        LD      A,(PAR_HL)
        AND     0FH
        JP      Z,AFC5B
        JP      AFC5E

; ----------------------------------------------

DIR_H:  LD      HL,PAR_HL
        LD      B,6
        XOR     A
AFC8B:  LD      (HL),A
        DEC     B
        JP      NZ,AFC8B
        LD      DE,0F77CH
        CALL    GET_HL
        LD      (PAR_HL),HL
        CALL    GET_HL
        LD      (PAR_DE),HL
        CALL    CR
        LD      HL,(PAR_HL)
        LD      (PAR_BC),HL
        EX      DE,HL
        LD      HL,(PAR_DE)
        ADD     HL,DE
        LD      (PAR_HL),HL
        CALL    PRPAR1
        LD      HL,(PAR_DE)
        EX      DE,HL
        LD      HL,(PAR_BC)
        LD      A,E
        CPL
        LD      E,A
        LD      A,D
        CPL
        LD      D,A
        INC     DE
        ADD     HL,DE
        LD      (PAR_HL),HL
        CALL    PRPAR1
        JP      CR

; ----------------------------------------------

DIR_I:  LD      A,0FFH
        CALL    LDBYTE
        LD      (0F752H),A
        LD      (0F75FH),A
        LD      A,8
        CALL    LDBYTE
        LD      (PAR_HL),A
        LD      (0F75EH),A
        LD      A,8
        CALL    LDBYTE
        LD      (0F754H),A
        LD      (0F761H),A
        LD      A,8
        CALL    LDBYTE
        LD      (PAR_DE),A
        LD      (0F760H),A
        LD      A,8
        LD      HL,AFD0C
        PUSH    HL
AFCFD:  LD      HL,(PAR_HL)
        CALL    LDBYTE
        LD      (HL),A
        CALL    AF97C
        LD      A,8
        JP      AFCFD

; ----------------------------------------------

AFD0C:  LD      HL,0F75FH
        CALL    AF96E
        LD      HL,0F761H
        CALL    AF96E
        JP      CR

; ----------------------------------------------

DIR_O:  CALL    GETPRM
        XOR     A
        LD      B,0
AFD21:  CALL    WRBYTE
        DEC     B
        JP      NZ,AFD21
        LD      A,0E6H
        CALL    WRBYTE
        LD      A,(0F752H)
        CALL    WRBYTE
        LD      A,(PAR_HL)
        CALL    WRBYTE
        LD      A,(0F754H)
        CALL    WRBYTE
        LD      A,(PAR_DE)
        CALL    WRBYTE
AFD45:  LD      HL,(PAR_HL)
        LD      A,(HL)
        CALL    WRBYTE
        CALL    AF97C
        JP      AFD45

; ----------------------------------------------

DIR_V:  LD      A,0FFH
        CALL    LDBYTE
        LD      (0F752H),A
        LD      A,8
        CALL    LDBYTE
        LD      (PAR_HL),A
        LD      A,8
        CALL    LDBYTE
        LD      (0F754H),A
        LD      A,8
        CALL    LDBYTE
        LD      (PAR_DE),A
AFD72:  LD      A,8
        CALL    LDBYTE
        LD      HL,(PAR_HL)
        CP      (HL)
        JP      Z,AFD8F
        PUSH    AF
        CALL    AF968
        CALL    SPACE
        CALL    AF94C
        CALL    SPACE
        POP     AF
        CALL    HEX_A
AFD8F:  CALL    AF97C
        JP      AFD72

; ----------------------------------------------

LDBYTE: PUSH    BC
        PUSH    DE
        LD      C,0
        LD      D,A
        IN      A,(1)
        LD      E,A
AFD9D:  LD      A,C
        AND     7FH
        RLCA
        LD      C,A
AFDA2:  IN      A,(1)
        CP      E
        JP      Z,AFDA2
        AND     1
        OR      C
        LD      C,A
        CALL    AFDDB
        IN      A,(1)
        LD      E,A
        LD      A,D
        OR      A
        JP      P,AFDD0
        LD      A,C
        CP      0E6H
        JP      NZ,AFDC4
        XOR     A
        LD      (0F757H),A
        JP      AFDCE

; ----------------------------------------------

AFDC4:  CP      19H
        JP      NZ,AFD9D
        LD      A,0FFH
        LD      (0F757H),A
AFDCE:  LD      D,9
AFDD0:  DEC     D
        JP      NZ,AFD9D
        LD      A,(0F757H)
        XOR     C
        POP     DE
        POP     BC
        RET

; ----------------------------------------------

AFDDB:  PUSH    AF
        LD      A,(0F75CH)
AFDDF:  LD      B,A
        POP     AF
AFDE1:  DEC     B
        JP      NZ,AFDE1
        RET

; ----------------------------------------------

WRBYTE: PUSH    BC
        PUSH    DE
        PUSH    AF
        LD      D,A
        LD      C,8
AFDEC:  LD      A,D
        RLCA
        LD      D,A
        LD      A,1
        XOR     D
        OUT     (1),A
        CALL    AFE07
        LD      A,0
        XOR     D
        OUT     (1),A
        CALL    AFE07
        DEC     C
        JP      NZ,AFDEC
        POP     AF
        POP     DE
        POP     BC
        RET

; ----------------------------------------------

AFE07:  PUSH    AF
        LD      A,(0F75DH)
        JP      AFDDF

; ----------------------------------------------

TBLREC  MACRO   Letter, ADDR
        DB    Letter
        DW      ADDR
        ENDM

; ----------------------------------------------

TABLE:  TBLREC  'M', DIR_M
        TBLREC  'C', DIR_C
        TBLREC  'D', DIR_D
        TBLREC  'B', DIR_B      ; Задание адреса останова при отладке
        TBLREC  'G', DIR_G
        TBLREC  'P', DIR_P      ; Подготовка к запуску циклически работающей программы
        TBLREC  'X', DIR_X
        TBLREC  'F', DIR_F
        TBLREC  'S', DIR_S
        TBLREC  'T', DIR_T
        TBLREC  'I', DIR_I
        TBLREC  'O', DIR_O
        TBLREC  'V', DIR_V      ; Сравнение записи на МГ-ленте с областью памяти
        TBLREC  'J', DIR_J      ; Запуск программы с заданного адреса
        TBLREC  'A', DIR_A      ; Вывод кода символа на экран
        TBLREC  'K', DIR_K      ; Вывод символа с клавиатуры на экран (окончание режима УС-А)
        TBLREC  'Q', DIR_Q      ; Тестирование области памяти
        TBLREC  'L', DIR_L      ; Просмотр области памяти в символьном виде
        TBLREC  'H', DIR_H      ; Расчёт суммы и разности двух HEX-чисел
        DB    0

PROMPT: DB    10,'*MikrO/80* MONITOR'
        DB    10,'>',0
T_CR:   DB    10,0

; ----------------------------------------------

COUT_A: PUSH    HL
        PUSH    BC
        PUSH    DE
        PUSH    AF
        LD      C,A
        JP      COUT

; ----------------------------------------------

COUT_C: PUSH    HL
        PUSH    BC
        PUSH    DE
        PUSH    AF
COUT:   LD      HL,(EK_ADR)
        LD      DE,-7FFH
        ADD     HL,DE
        LD      (HL),0          ; гасим курсор
        LD      HL,(EK_ADR)     ; короче PUSH-POP
        LD      A,C
        CP      1FH
        JP      Z,CLS
        CP      8
        JP      Z,COD_08
        CP      18H
        JP      Z,COD_18
        CP      19H
        JP      Z,COD_19
        CP      1AH
        JP      Z,COD_1A
        CP      0AH
        JP      Z,COD_0A
        CP      0CH
        JP      Z,HOME
        LD      A,H
        CP      0F0H
        JP      NZ,AFEB2

        CALL    STATUS
        OR      A
        JP      Z,AFEAC
        CALL    CONIN
AFEAC:  CALL    CLSSCR

        LD      HL,0E800H
AFEB2:  LD      (HL),C
        INC     HL
AFEB4:  LD      (EK_ADR),HL
        LD      DE,-7FFH
        ADD     HL,DE
        LD      (HL),80H        ; зажечь курсор
        POP     AF
        POP     DE
        POP     BC
        POP     HL
        RET

; ----------------------------------------------

CLS:    CALL    CLSSCR
HOME:   LD      HL,0E800H
        JP      AFEB4

; ----------------------------------------------

CLSSCR: LD      HL,0E800H
        LD      DE,0E000H
AFED1:  LD      (HL),20H
        INC     HL
        LD      A,0             ; XOR A
        LD      (DE),A
        INC     DE
        LD      A,H
        CP      0F0H
        RET     Z
        JP      AFED1

; ----------------------------------------------

COD_18: INC     HL
        LD      A,H
        CP      0F0H
        JP      NZ,AFEB4
        JP      Z,HOME
COD_08: DEC     HL
        LD      A,H
        CP      0E7H
        JP      NZ,AFEB4
        LD      HL,0EFFFH
        JP      AFEB4

; ----------------------------------------------

COD_1A: LD      DE,64
        ADD     HL,DE
        LD      A,H
        CP      0F0H
        JP      NZ,AFEB4
        LD      H,0E8H
        JP      AFEB4

; ----------------------------------------------

COD_19: LD      DE,-64
        ADD     HL,DE
        LD      A,H
        CP      0E7H
        JP      NZ,AFEB4
        LD      DE,800H
        ADD     HL,DE
        JP      AFEB4

; ----------------------------------------------

COD_0A: INC     HL
        LD      A,L
        OR      A
        JP      Z,AFF2E
        CP      40H
        JP      Z,AFF2E
        CP      80H
        JP      Z,AFF2E
        CP      0C0H
        JP      Z,AFF2E
        JP      COD_0A

; ----------------------------------------------

AFF2E:  LD      A,H
        CP      0F0H
        JP      NZ,AFEB4
        CALL    STATUS
        OR      A
        JP      Z,CLS
        CALL    CONIN
        JP      CLS

; ----------------------------------------------

CONIN:  PUSH    BC
        PUSH    DE
        PUSH    HL
AFF44:  LD      B,0
        LD      C,0FEH
        LD      D,8
AFF4A:  LD      A,C
        OUT     (7),A
        RLCA
        LD      C,A
        IN      A,(6)
        AND     7FH
        CP      7FH
        JP      NZ,AFF63
        LD      A,B
        ADD     A,7
        LD      B,A
        DEC     D
        JP      NZ,AFF4A
        JP      AFF44

; ----------------------------------------------

AFF63:  LD      (0F764H),A
AFF66:  RRA
        JP      NC,AFF6E
        INC     B
        JP      AFF66

; ----------------------------------------------

AFF6E:  LD      A,B
        CP      30H
        JP      NC,AFF86
        ADD     A,30H
        CP      3CH
        JP      C,AFF82
        CP      40H
        JP      NC,AFF82
        AND     101111B
AFF82:  LD      C,A
        JP      AFF93

; ----------------------------------------------

AFF86:  LD      HL,TABK
        SUB     30H
        LD      C,A
        LD      B,0
        ADD     HL,BC
        LD      A,(HL)
        JP      AFFC7

; ----------------------------------------------

AFF93:  IN      A,(5)
        AND     7
        CP      7
        JP      Z,AFFC6
        RRA
        RRA
        JP      NC,AFFAB
        RRA
        JP      NC,AFFB1
        LD      A,C
        OR      20H
        JP      AFFC7

; ----------------------------------------------

AFFAB:  LD      A,C
        AND     1FH
        JP      AFFC7

; ----------------------------------------------

AFFB1:  LD      A,C
        CP      40H
        JP      NC,AFFC7
        CP      30H
        JP      NC,AFFC1
        OR      10H
AFFBE:  JP      AFFC7

; ----------------------------------------------

AFFC1:  AND     101111B
        JP      AFFC7

; ----------------------------------------------

AFFC6:  LD      A,C
AFFC7:  LD      C,A
        CALL    PAUSE
        LD      HL,0F764H
AFFCE:  IN      A,(6)
        CP      (HL)
        JP      Z,AFFCE
        CALL    PAUSE
        LD      A,C
        POP     HL
        POP     DE
        POP     BC
        RET

; ----------------------------------------------

PAUSE:  LD      DE,800H
PAUSLO: DEC     DE
        LD      A,D
        OR      E
        RET     Z
        JP      PAUSLO

; ----------------------------------------------

TABK:   DB    20H,18H,8,19H,1AH,0DH,1FH,0CH

; ----------------------------------------------

STATUS: LD      A,0
        OUT     (7),A
        IN      A,(6)
        AND     7FH
        CP      7FH
        JP      NZ,AFFFD
        XOR     A
        RET

; ----------------------------------------------

AFFFD:  LD      A,0FFH
        RET

; ----------------------------------------------


        END

