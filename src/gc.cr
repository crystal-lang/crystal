module GC
  def self.malloc(size : UInt32)
    __crystal_malloc(size)
  end

  def self.malloc_atomic(size : UInt32)
    __crystal_malloc_atomic(size)
  end

  def self.realloc(pointer : Void*, size : UInt32)
    __crystal_realloc(pointer, size)
  end
end
