.text
.globl _start
_start:

  call _save_regs

  #place our "hello!!\n" string on the stack
  movq $0x0000000a21646c72, %rcx
  pushq %rcx
  movq $0x6f57206f6c6c6548, %rcx
  pushq %rcx
  movq %rsp, %rsi

  #write syscall = 1
  movq $1, %rax
  #print to stdout
  movq $1, %rdi
  #8 character long string
  movq $13, %rdx

  syscall

  pop %rcx
  pop %rcx

  jmp _exec_victim

#Save all registers
_save_regs:
  pop %rcx

  push %rax
  push %rbx
  push %rdx
  push %rdi
  push %rsi

  push %rcx
  ret

#Load the original value of all registers
_load_regs:
  pop %rcx

  pop %rsi
  pop %rdi
  pop %rdx
  pop %rbx
  pop %rax

  push %rcx
  ret

_exec_victim:
  call _load_regs
  jmp _old_entry
_pop_entry:
  pop %rcx
  mov (%rcx), %rcx
  jmp *%rcx
_old_entry:
  call _pop_entry
