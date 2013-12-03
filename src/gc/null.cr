lib C
  fun malloc(size : UInt32) : Void*
  fun realloc(ptr : Void*, size : UInt32) : Void*
end

fun __crystal_malloc(size : UInt32) : Void*
  C.malloc(size)
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  C.realloc(ptr, size)
end
