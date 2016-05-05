require "./types"

lib LibC
  PROT_EXEC             =  0x4
  PROT_NONE             =  0x0
  PROT_READ             =  0x1
  PROT_WRITE            =  0x2
  MAP_FIXED             = 0x10
  MAP_PRIVATE           = 0x02
  MAP_SHARED            = 0x01
  MAP_ANON              = LibC::MAP_ANONYMOUS
  MAP_ANONYMOUS         = 0x20
  MAP_FAILED            = Pointer(Void).new(-1)
  POSIX_MADV_DONTNEED   =  4
  POSIX_MADV_NORMAL     =  0
  POSIX_MADV_RANDOM     =  1
  POSIX_MADV_SEQUENTIAL =  2
  POSIX_MADV_WILLNEED   =  3
  MADV_DONTNEED         =  4
  MADV_NORMAL           =  0
  MADV_RANDOM           =  1
  MADV_SEQUENTIAL       =  2
  MADV_WILLNEED         =  3
  MADV_HUGEPAGE         = 14
  MADV_NOHUGEPAGE       = 15

  fun mmap(addr : Void*, len : SizeT, prot : Int, flags : Int, fd : Int, offset : OffT) : Void*
  fun mprotect(addr : Void*, len : SizeT, prot : Int) : Int
  fun munmap(addr : Void*, len : SizeT) : Int
  fun madvise(addr : Void*, len : SizeT, advice : Int) : Int
end
