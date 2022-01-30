all:
	nasm -f elf myprint.asm -o myprint.o
	gcc -m32 main.c myprint.o -o fatcmd -g
	rm myprint.o
	./fatcmd
