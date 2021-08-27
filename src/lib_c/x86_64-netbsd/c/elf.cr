require "./sys/types"

lib LibC
  alias Elf_Half = UInt16T
  alias Elf_Word = UInt32T
  alias Elf_Sword = Int32T
  alias Elf_Xword = UInt64T
  alias Elf_Sxword = Int64T
  alias Elf_Addr = UInt64T
  alias Elf_Off = UInt64T
  alias Elf_Section = UInt16T
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
