asw -lU monitor.asm > monitor.lst
p2bin monitor.p monitor.bin

asw -lU cpm64-term.asm > cpm64-term.lst
p2bin cpm64-term.p cpm64-term.bin

asw -lU cpm64-bios.asm > cpm64-bios.lst
p2bin cpm64-bios.p cpm64-bios.bin

asw -lU cpm64-bdos.asm > cpm64-bdos.lst
p2bin cpm64-bdos.p cpm64-bdos.bin

asw -lU cpm64-ccp.asm > cpm64-ccp.lst
p2bin cpm64-ccp.p cpm64-ccp.bin

asw -lU cpm64-loader.asm > cpm64-loader.lst
p2bin cpm64-loader.p cpm64-loader.bin

asw -lU ch-com.asm > ch-com.lst
p2bin ch-com.p ch-com.bin

bin2rk cpm64-loader.bin 12544

asw -lU basic80.asm > basic80.lst
p2bin basic80.p basic80.bin
bin2rk basic80.bin

bin2rk ctrlbas.bin
