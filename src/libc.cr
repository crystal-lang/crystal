lib LibC
  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  ifdef x86_64
    alias IntT = Int64
    alias UIntT = UInt64
    alias LongT = Int64
  else
    alias IntT = Int32
    alias UIntT = UInt32
    alias LongT = Int32
  end

  alias PtrDiffT = IntT
  alias SizeT = UIntT
  alias SSizeT = IntT
  alias TimeT = IntT

  fun malloc(size : UInt32) : Void*
  fun realloc(ptr : Void*, size : UInt32) : Void*
  fun free(ptr : Void*)
  fun time(t : Int64) : Int64
  fun free(ptr : Void*)
  fun memcmp(p1 : Void*, p2 : Void*, size : LibC::SizeT) : Int32

  PROT_NONE = 0x00
  PROT_READ = 0x01
  PROT_WRITE = 0x02
  PROT_EXEC = 0x04
  MAP_SHARED = 0x0001
  MAP_PRIVATE = 0x0002

  ifdef darwin
    MAP_ANON = 0x1000
  end
  ifdef linux
    MAP_ANON = 0x0020
  end

  fun mmap(addr : Void*, len : SizeT, prot : Int32, flags : Int32, fd : Int32, offset : Int32) : Void*
  fun munmap(addr : Void*, len : SizeT)
end
