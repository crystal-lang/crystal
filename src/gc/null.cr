fun __crystal_malloc(size : UInt32) : Void*
  ptr = LibC.malloc(size)
  Intrinsics.memset(ptr, 0_u8, size, 0_u32, false)
  ptr
end

fun __crystal_malloc_atomic(size : UInt32) : Void*
  ptr = LibC.malloc(size)
  Intrinsics.memset(ptr, 0_u8, size, 0_u32, false)
  ptr
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  ptr = LibC.realloc(ptr, size)
  # needs zeroing
end

module GC
  def self.init
  end

  def self.collect
  end

  def self.enable
  end

  def self.disable
  end

  def self.free(pointer : Void*)
    LibC.free(pointer)
  end

  def self.add_finalizer(object)
  end
end
