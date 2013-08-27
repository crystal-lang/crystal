class GC
  @@objects_size = 1024_u64
  @@objects_index = 0
  @@objects = Pointer(Pointer(Void)).malloc(@@objects_size)

  @@roots_size = 1024_u64
  @@roots_index = 0
  @@roots = Pointer(Pointer(Void)).malloc(@@roots_size)

  def self.malloc(size : Int32)
    pointer = Pointer(Void).malloc(size + 1)

    add_object pointer
    add_root pointer

    pointer + 1
  end

  def self.add_object(pointer)
    @@objects[@@objects_index] = pointer
    @@objects_index += 1

    if @@objects_index == @@objects_size
      @@objects_size *= 2
      @@objects = @@objects.realloc(@@objects_size)
    end
  end

  def self.add_root(pointer)
    @@roots[@@roots_index] = pointer
    @@roots_index += 1

    if @@roots_index == @@roots_size
      @@roots_size *= 2
      @@roots = @@roots.realloc(@@roots_size)
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

fun __crystal_gc_add_root(pointer : Void*) : Void
  GC.add_root pointer
end

fun __crystal_gc_get_root_index : Int32
  GC.root_index
end

fun __crystal_gc_set_root_index(index : Int32) : Int32
  GC.root_index = index
end
