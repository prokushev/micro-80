:asw -lU ccp.z80 > lst
:p2bin ccp.p ccp.bin

:asw -lU monorig.asm > lst
:p2bin monorig.p monorig.bin

:asw -lU cpm64-bios.asm > lst
:p2bin cpm64-bios.p cpm64-bios.bin

:asw -lU cpm64-term.asm > lst
:p2bin cpm64-term.p cpm64-term.bin

asw -lU cpm64-loader.asm > lst
p2bin cpm64-loader.p cpm64-loader.bin
