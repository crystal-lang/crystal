lib LibC
  ifdef x86_64
    alias SizeT = UInt64
    alias SSizeT = Int64
  else
    alias SizeT = UInt32
    alias SSizeT = Int32
  end

  #ifdef windows
  #alias LongT = Int32
  #else
  alias LongT = SSizeT
  #end

  alias PtrDiffT = SSizeT

  alias TimeT = Int64

  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  fun malloc(size : SizeT) : Void*
  fun realloc(ptr : Void*, size : SizeT) : Void*
  fun free(ptr : Void*)
  fun time(t : TimeT*) : TimeT
  fun free(ptr : Void*)
  fun memcmp(p1 : Void*, p2 : Void*, size : SizeT) : Int32
end
