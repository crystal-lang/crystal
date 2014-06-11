fun __crystal_malloc(size : UInt32) : Void*
  C.malloc(size)
end

fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  C.realloc(ptr, size)
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
    C.free(pointer)
  end

  def self.add_finalizer(object)
  end
end
