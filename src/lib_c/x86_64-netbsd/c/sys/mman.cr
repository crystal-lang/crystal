require "./types"

lib LibC
  PROT_NONE             =   0x00
  PROT_READ             =   0x01
  PROT_WRITE            =   0x02
  PROT_EXEC             =   0x04
  MAP_SHARED            = 0x0001
  MAP_PRIVATE           = 0x0002
  MAP_FIXED             = 0x0010
  MAP_ANON              = 0x1000
  MAP_ANONYMOUS         = LibC::MAP_ANON
  MAP_FAILED            = Pointer(Void).new(-1)
  MAP_STACK             = 0x2000
  POSIX_MADV_NORMAL     =      0
  POSIX_MADV_RANDOM     =      1
  POSIX_MADV_SEQUENTIAL =      2
  POSIX_MADV_WILLNEED   =      3
  POSIX_MADV_DONTNEED   =      4
  MADV_NORMAL           = LibC::POSIX_MADV_NORMAL
  MADV_RANDOM           = LibC::POSIX_MADV_RANDOM
  MADV_SEQUENTIAL       = LibC::POSIX_MADV_SEQUENTIAL
  MADV_WILLNEED         = LibC::POSIX_MADV_WILLNEED
  MADV_DONTNEED         = LibC::POSIX_MADV_DONTNEED

  fun mmap(x0 : Void*, x1 : SizeT, x2 : Int, x3 : Int, x4 : Int, x5 : OffT) : Void*
  fun mprotect(x0 : Void*, x1 : SizeT, x2 : Int) : Int
  fun munmap(x0 : Void*, x1 : SizeT) : Int
  fun madvise(x0 : Void*, x1 : SizeT, x2 : Int) : Int
end
