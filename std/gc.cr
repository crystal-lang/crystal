lib C
  fun malloc(size : Int32) : Void*
  fun realloc(pointer : Void*, size : Int32) : Void*
end

class GC
  @@objects_size = 1024
  @@objects_index = 0
  @@objects = C.malloc(@@objects_size * 8).as(Pointer(Pointer(Void)))

  @@roots_size = 1024
  @@roots_index = 0
  @@roots = C.malloc(@@roots_size * 8).as(Pointer(Pointer(Void)))

  def self.malloc(size : Int32)
    pointer = C.malloc(size + 1)

    add_object pointer
    add_root pointer

    pointer + 1
  end

  def self.realloc(pointer : Pointer(Void), size : Int32)
    pointer = C.realloc(pointer - 1, size + 1)
    pointer + 1
  end

  def self.add_object(pointer)
    @@objects[@@objects_index] = pointer
    @@objects_index += 1

    if @@objects_index == @@objects_size
      @@objects_size *= 2
      @@objects = C.realloc(@@objects.as(Void), @@objects_size * 8).as(Pointer(Pointer(Void)))
    end
  end

  def self.add_root(pointer)
    @@roots[@@roots_index] = pointer
    @@roots_index += 1

    if @@roots_index == @@roots_size
      @@roots_size *= 2
      @@roots = C.realloc(@@roots.as(Void), @@roots_size * 8).as(Pointer(Pointer(Void)))
    end
  end

  def self.root_index
    @@roots_index
  end

  def self.root_index=(value)
    @@roots_index = value
  end
end

fun __crystal_malloc(size : Int32) : Void*
  GC.malloc size
end

fun __crystal_realloc(pointer : Void*, size : Int32) : Void*
  GC.realloc pointer, size
end

fun __crystal_gc_add_root(pointer : Void*) : Void
  GC.add_root pointer
end

fun __crystal_gc_get_root_index : Int32
  GC.root_index
end

fun __crystal_gc_set_root_index(index : Int32) : Int32
  GC.root_index = index
end
