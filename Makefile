# MPLAB IDE generated this makefile for use with GNU make.
# Project: Project.mcp
# Date: Mon Jan 01 18:03:04 2024

AS = MPASMWIN.exe
CC = 
LD = mplink.exe
AR = mplib.exe
RM = rm

Project.cof : Project.o
	$(CC) /p16F877A "Project.o" /u_DEBUG /z__MPLAB_BUILD=1 /z__MPLAB_DEBUG=1 /o"Project.cof" /M"Project.map" /W /x

Project.o : Project.asm p16f877a.inc
	$(AS) /q /p16F877A "Project.asm" /l"Project.lst" /e"Project.err" /d__DEBUG=1

clean : 
	$(CC) "Project.o" "Project.hex" "Project.err" "Project.lst" "Project.cof"

