module GC
  def self.malloc(size : UInt32)
    __crystal_malloc(size)
  end

  def self.realloc(pointer : Void*, size : UInt32)
    __crystal_realloc(pointer, size)
  end
end
