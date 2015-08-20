module GC
  def self.malloc(size : Int)
    __crystal_malloc(size.to_u32)
  end

  def self.malloc_atomic(size : Int)
    __crystal_malloc_atomic(size.to_u32)
  end

  def self.realloc(pointer : Void*, size : Int)
    __crystal_realloc(pointer, size.to_u32)
  end
end
