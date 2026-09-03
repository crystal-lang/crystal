require "./sys/types"

lib LibC
  alias Elf_Addr = ULong
  alias Elf_Half = UShort
  alias Elf_Off = ULong
  alias Elf_Sword = Int
  alias Elf_Sxword = Long
  alias Elf_Word = UInt
  alias Elf_Xword = ULong
  alias Elf_Versym = Elf_Half

  struct Elf_Phdr
    type : Elf_Word    # Segment type
    flags : Elf_Word   # Segment flags
    offset : Elf_Off   # Segment file offset
    vaddr : Elf_Addr   # Segment virtual address
    paddr : Elf_Addr   # Segment physical address
    filesz : Elf_Xword # Segment size in file
    memsz : Elf_Xword  # Segment size in memory
    align : Elf_Xword  # Segment alignment
  end
end
