lib C
  fun malloc(size : Int32) : Void*
  fun realloc(pointer : Void*, size : Int32) : Void*
end

class GC
  @@table_size = 1024
  @@table_entry = 0
  @@table = C.malloc(@@table_size * 8).as(Pointer(Pointer(Void)))

  def self.malloc(size : Int32)
    pointer = C.malloc(size + 1)

    @@table[@@table_entry] = pointer
    @@table_entry += 1

    if @@table_entry == @@table_size
      @@table_size *= 2
      @@table = C.realloc(@@table.as(Void), @@table_size * 8).as(Pointer(Pointer(Void)))
    end

    pointer + 1
  end

  def self.realloc(pointer : Pointer(Void), size : Int32)
    pointer = C.realloc(pointer - 1, size + 1)
    pointer + 1
  end
end

fun __crystal_malloc(size : Int32) : Void*
  GC.malloc size
end

fun __crystal_realloc(pointer : Void*, size : Int32) : Void*
  GC.realloc pointer, size
end
