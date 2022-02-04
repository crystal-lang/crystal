require "./types"

lib LibC
  PROT_EXEC             =    4
  PROT_NONE             =    0
  PROT_READ             =    1
  PROT_WRITE            =    2
  MAP_FIXED             = 0x10
  MAP_PRIVATE           = 0x02
  MAP_SHARED            = 0x01
  MAP_ANON              = 0x20
  MAP_ANONYMOUS         = LibC::MAP_ANON
  MAP_FAILED            = Pointer(Void).new(-1)
  POSIX_MADV_DONTNEED   =  0
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

  fun mmap(x0 : Void*, x1 : SizeT, x2 : Int, x3 : Int, x4 : Int, x5 : OffT) : Void*
  fun mprotect(x0 : Void*, x1 : SizeT, x2 : Int) : Int
  fun munmap(x0 : Void*, x1 : SizeT) : Int
  fun madvise(x0 : Void*, x1 : SizeT, x2 : Int) : Int
end
