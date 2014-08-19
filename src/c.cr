lib C
  ifdef darwin
    alias ModeT = UInt16
  elsif linux
    alias ModeT = UInt32
  end

  ifdef x86_64
    alias SizeT = UInt64
    alias TimeT = Int64
  else
    alias SizeT = UInt32
    alias TimeT = Int32
  end

  fun malloc(size : UInt32) : Void*
  fun realloc(ptr : Void*, size : UInt32) : Void*
  fun free(ptr : Void*)
  fun time(t : Int64) : Int64
  fun free(ptr : Void*)
  fun memcmp(p1 : Void*, p2 : Void*, size : C::SizeT) : Int32
end
