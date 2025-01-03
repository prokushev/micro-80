# РЛК МИКРО-80

## Аппаратное обеспечение

Используется конфигурация, опубликованная в журналах. Никаких собственных или сторонних дополнений не
подразумевается.

## Программное обеспечение

Программное обеспечение включает в себя:

- МОНИТОР (опубликован в журналах Радио 1983 год №11 и №12)
- БЕЙСИК (опубликован в журналах Радио 1985 год №1, №2, №3)
- БЕЙСИК-СЕРВИС (опубликован в журнале Радио 1988 год №1)
- CP/M (опубликован в журналах Микропроцеcсорные средства и системы 1984 год №4 и в ЮТ для умелых рук 1990 год №1)
- МОНИТОР-РК86 (опубликован в журнале Радио 1989 год №11)

Большинство программ были дизассемблированы и представлены в исходном тексте.
Первичная сборка осуществлялась один в один с опубликованными, после чего были
внесены различные изменеия и дополнения.

МОНИТОР без изменений. Соответсвие двоичного образа опубликованному не проводилось,
т.к. контрольные суммы не были опубликованы.

БЕЙСИК двоично соответствует опубликованному, проверено с помощью программы подсчота
контрольных сумм (опубликована там же). На исходный текст наложены коментарии от
Altair BASIC. Проект в отдельном репозитории.

CP/M, опубликованная для ЮТ-88, судя по сопоставлению опубликованного кода в МПСиС и
дизассемблированного кода, является той же самой разработкой с несущественными модификациями.
Было увеличего количество блоков ОЗУ с 4 до 8 (в соответствии с электрической схемой).
BIOS восстановлен по публикации в МПСиС и дизассемблеру публикации в ЮТ и оригинальных
исходных текстов CP/M. BDOS и CPP двоично те же самые, что и оригинальные исходные тексты
CP/M. Проект в отдельном репозитории

МОНИТОР-РК86 двоично сопоставлен с опубликованным. Т.к. в нем имеется критическая ошибка,
внесены изменения по ее исправлению. Так же в отдельном репозитории программа управления
ROM-диском, работающая на Радио-86РК, Микро-80, ЮТ-88.

## Лицензионные вопросы

