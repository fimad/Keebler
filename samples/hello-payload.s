.text
.globl _start
_start:
  #save the base pointer
  pushq %rbp
  pushq %rbx
  mov %rsp,%rbp

  #write syscall = 1
  movq $1, %rax
  #print to stdout
  movq $1, %rbx
  #8 character long string
  movq $13, %rdx

  #place our "hello!!\n" string on the stack
  movq $0x0000000a21646c72, %rcx
  pushq %rcx
  movq $0x6f57206f6c6c6548, %rcx
  pushq %rcx
  movq %rsp, %rsi

  syscall

  #remove the string
  pop %rcx
  pop %rcx

  pop %rbx
  pop %rbp
  ret
