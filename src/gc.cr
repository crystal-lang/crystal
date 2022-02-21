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

  record ProfStats,
    heap_size : LibC::ULong,
    free_bytes : LibC::ULong,
    unmapped_bytes : LibC::ULong,
    bytes_since_gc : LibC::ULong,
    bytes_before_gc : LibC::ULong,
    non_gc_bytes : LibC::ULong,
    gc_no : LibC::ULong,
    markers_m1 : LibC::ULong,
    bytes_reclaimed_since_gc : LibC::ULong,
    reclaimed_bytes_before_gc : LibC::ULong

  # Allocates and clears *size* bytes of memory.
  #
  # The resulting object may contain pointers and they will be tracked by the GC.
  #
  # The memory will be automatically deallocated when unreferenced.
  def self.malloc(size : Int) : Void*
    malloc(LibC::SizeT.new(size))
  end

  # Allocates *size* bytes of pointer-free memory.
  #
  # The client promises that the resulting object will never contain any pointers.
  #
  # The memory is not cleared. It will be automatically deallocated when unreferenced.
  def self.malloc_atomic(size : Int) : Void*
    malloc_atomic(LibC::SizeT.new(size))
  end

  # Changes the allocated memory size of *pointer* to *size*.
  # If this can't be done in place, it allocates *size* bytes of memory and
  # copies the content of *pointer* to the new location.
  #
  # If *pointer* was allocated with `malloc_atomic`, the same constraints apply.
  #
  # The return value is a pointer that may be identical to *pointer* or different.
  def self.realloc(pointer : Void*, size : Int) : Void*
    realloc(pointer, LibC::SizeT.new(size))
  end
end

{% if flag?(:gc_none) %}
  require "gc/none"
{% else %}
  require "gc/boehm"
{% end %}
