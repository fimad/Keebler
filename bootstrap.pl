#!/usr/bin/perl
use strict;
use Getopt::Long;
use File::Temp qw/tempfile/;

my $_ELF;
my $_TEMPLATE;
my $_OUTPUT;

GetOptions(
    "elf=s" => \$_ELF
  , "template=s" => \$_TEMPLATE
  , "output=s" => \$_OUTPUT
);

if( !$_ELF or !$_TEMPLATE or !$_OUTPUT){
  die("usage: $0 -e elfFile -t bootstrap.s -o payload\n");
}

#read the entire elf and template into memory
my $elfData;
my $template;
{
  local $/ = undef;
  open FILE, "$_ELF" or die "Couldn't open file: $!";
  binmode FILE;
  $elfData = <FILE>;
  close FILE;

  open FILE, "$_TEMPLATE" or die "Couldn't open file: $!";
  binmode FILE;
  $template = <FILE>;
  close FILE;
}

#encode the elf into something gas can understand
my $elfSize = length $elfData;
#my @encodedElf = ;
my $encodedElf = ".byte " . join(",", map {ord($_)+""} split(//,$elfData));

$template =~ s/\<_elf_size\>/.int $elfSize/g;
$template =~ s/\<_elf_data\>/$encodedElf/g;

my ($asmFH,$asmFilePath) = tempfile("keebler-bootstrapXXXXXXXX", DIR=>"/tmp");
my ($o,$oFilePath) = tempfile("keebler-bootstrapXXXXXXXX", DIR=>"/tmp");
close($o);
print $asmFH $template;
close($asmFH);

print `as $asmFilePath -o $oFilePath`;
unlink($asmFilePath);

print `objcopy -O binary $oFilePath $_OUTPUT`;
unlink($oFilePath);
