.text
.globl _start
_start:
  push %ebp
  mov %esp,%ebp
  push %edi
  push %esi
  push %ebx

#push the string "Hello World!\n" on the stack
  mov $0x0000000a, %ecx
  push %ecx
  mov $0x21646c72, %ecx
  push %ecx
  mov $0x6f57206f, %ecx
  push %ecx
  mov $0x6c6c6548, %ecx
  push %ecx
  mov %esp, %ecx

#print to stdout
  mov $1, %ebx

#string length is 13
  mov $13, %edx

#write syscall
  mov $4, %eax

  int $0x80

#remove our string from the stack
  pop %ecx
  pop %ecx
  pop %ecx
  pop %ecx

  pop %ebx
  pop %esi
  pop %edi
  pop %ebp
  ret
