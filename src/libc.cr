lib LibC
  ifdef x86_64
    alias SizeT = UInt64
    alias SSizeT = Int64
  else
    alias SizeT = UInt32
    alias SSizeT = Int32
  end

  alias Char = UInt8
  alias SChar = Int8
  alias Short = Int16
  alias UShort = UInt16
  alias Int = Int32
  alias UInt = UInt32
  alias Long = SSizeT
  alias ULong = SizeT
  alias LongLong = Int64
  alias ULongLong = UInt64
  alias Float = Float32
  alias Double = Float64

  alias PtrDiffT = SSizeT
  alias TimeT = SSizeT
  alias PidT = Int

  ifdef musl
    alias OffT = Int64
  else
    alias OffT = SSizeT
  end

  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  ifdef darwin
    alias UsecT = Int32
  else
    alias UsecT = Long
  end

  # This is for __builtin_va_list
  ifdef x86_64
    alias VaList = UInt8[24]
  else
    alias VaList = UInt32
  end

  fun malloc(size : SizeT) : Void*
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun free(ptr : Void*)
  fun free(ptr : Void*)
  fun memcmp(p1 : Void*, p2 : Void*, size : SizeT) : Int32
  fun _exit(status : Int) : NoReturn

  PROT_NONE   =   0x00
  PROT_READ   =   0x01
  PROT_WRITE  =   0x02
  PROT_EXEC   =   0x04
  MAP_SHARED  = 0x0001
  MAP_PRIVATE = 0x0002

  ifdef darwin
    MAP_ANON = 0x1000
  end
  ifdef linux
    MAP_ANON = 0x0020
  end

  MAP_FAILED = Pointer(Void).new(SizeT.new(-1))

  fun mmap(addr : Void*, len : SizeT, prot : Int, flags : Int, fd : Int, offset : OffT) : Void*
  fun munmap(addr : Void*, len : SizeT)
  fun madvise(addr : Void*, len : SizeT, advise : Int) : Int
  fun mprotect(addr : Void*, len : SizeT, prot : Int) : Int

  MADV_NORMAL     = 0
  MADV_RANDOM     = 1
  MADV_SEQUENTIAL = 2
  MADV_WILLNEED   = 3
  MADV_DONTNEED   = 4

  ifdef linux
    MADV_HUGEPAGE   = 14
    MADV_NOHUGEPAGE = 15
  end

  # used by [event, io, time]
  struct TimeSpec
    tv_sec : LibC::TimeT
    tv_nsec : LibC::TimeT
  end

  # used by [file/stat, time]
  struct TimeVal
    tv_sec : LibC::TimeT
    tv_usec : LibC::UsecT
  end
end

# These new definitions are here because they are required before defining
# all of Number, Int, etc., functionality (for example in GC)

def Int8.new(value)
  value.to_i8
end

def Int16.new(value)
  value.to_i16
end

def Int32.new(value)
  value.to_i32
end

def Int64.new(value)
  value.to_i64
end

def UInt8.new(value)
  value.to_u8
end

def UInt16.new(value)
  value.to_u16
end

def UInt32.new(value)
  value.to_u32
end

def UInt64.new(value)
  value.to_u64
end

def Float32.new(value)
  value.to_f32
end

def Float64.new(value)
  value.to_f64
end
