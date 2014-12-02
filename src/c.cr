lib C
  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  ifdef x86_64
    alias IntT = Int64
    alias UIntT = UInt64
  else
    alias IntT = Int32
    alias UIntT = UInt32
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
  fun memcmp(p1 : Void*, p2 : Void*, size : C::SizeT) : Int32
end
