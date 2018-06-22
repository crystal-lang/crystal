# :nodoc:
fun __crystal_malloc(size : UInt32) : Void*
  GC.malloc(LibC::SizeT.new(size))
end

# :nodoc:
fun __crystal_malloc_atomic(size : UInt32) : Void*
  GC.malloc_atomic(LibC::SizeT.new(size))
end

# :nodoc:
fun __crystal_realloc(pointer : Void*, size : UInt32) : Void*
  GC.realloc(pointer, LibC::SizeT.new(size))
end

# :nodoc:
fun __crystal_malloc64(size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  GC.malloc(LibC::SizeT.new(size))
end

# :nodoc:
fun __crystal_malloc_atomic64(size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  GC.malloc_atomic(LibC::SizeT.new(size))
end

# :nodoc:
fun __crystal_realloc64(ptr : Void*, size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  GC.realloc(ptr, LibC::SizeT.new(size))
end

module GC
  record Stats,
    # collections : LibC::ULong,
    # bytes_found : LibC::Long,
    heap_size : LibC::ULong,
    free_bytes : LibC::ULong,
    unmapped_bytes : LibC::ULong,
    bytes_since_gc : LibC::ULong,
    total_bytes : LibC::ULong

  def self.malloc(size : Int)
    malloc(LibC::SizeT.new(size))
  end

  def self.malloc_atomic(size : Int)
    malloc_atomic(LibC::SizeT.new(size))
  end

  def self.realloc(pointer : Void*, size : Int)
    realloc(pointer, LibC::SizeT.new(size))
  end
end

{% if flag?(:gc_none) %}
  require "gc/none"
{% else %}
  require "gc/boehm"
{% end %}
