Keebler
=======

Keebler is a tool for injecting standalone binary payloads into ELF executables.
The payload is inserted at the end of the segment containing the target's .text section.
Execution of the payload is achieved by modifying the .ctors section to point to the first byte of the payload.
In order to not interrupt the normal functioning of the target program, the payload must behave like a function.
That means it must return, and it must restore any registers that the target's policy requires (typically base pointer and \*bx).


Compiling
---------

Compiling is as simple as running `make` in the base directory.
This will produce `keebler32` and `keebler64` for working with 32 bit and 64 bit ELF files respectively.


Payloads
--------

Because the payloads must be standalone they cannot depend on any runtime linking (i.e. you cannot use library routines).
This basically limits you to writing and dealing with assembly.
Some sample payloads are supplied to give you an idea what a valid payload looks like.

Preparing a payload involves assembling it with `as` (producing an elf object).
And then extracting just the assembled code with `objcopy`.

    as payload.s -o payload.o
    objcopy -O binary payload.o payload


Infecting
---------

Infecting an elf file is as easy as running:

    keebler64 target payload result

It is valid to have result be the same file as target as the entire file is copied into memory before altering.

