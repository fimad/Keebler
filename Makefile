CC=gcc
CFLAGS=

all : keebler32 keebler64

keebler32 : keebler32.c keebler_generic.c
	${CC} -o keebler32 keebler32.c

keebler64 : keebler64.c keebler_generic.c
	${CC} -o keebler64 keebler64.c

clean :
	rm keebler32 keebler64
