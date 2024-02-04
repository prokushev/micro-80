asw -lU monitor.asm > monitor.lst
p2bin monitor.p monitor.bin

asw -lU monitor-rk86.asm > monitor-rk86.lst
p2bin monitor-rk86.p monitor-rk86.bin

asw -lU romdisk.asm > romdisk.lst
p2bin romdisk.p romdisk.bin
