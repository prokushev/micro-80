@echo off

SET PATH=tools;%PATH%

echo MONITOR
asw -q -lU src\monitor\monitor.asm > monitor.lst
p2bin src\monitor\monitor.p rom\monitor.bin

echo MONITOR RADIO-86RK
asw -lU src\m80k\monitor-rk86.asm > monitor-rk86.lst
p2bin src\m80k\monitor-rk86.p rom\monitor-rk86.bin

echo ROMCTRL
cd src\romctrl
call make
cd ..\..

echo ROM-disk
asw -lU -i src\romctrl\roms -i bin src\romdisk\romdisk.asm > romdisk.lst
p2bin src\romdisk\romdisk.p rom\romdisk.bin
