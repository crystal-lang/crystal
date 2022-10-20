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
{% if flag?(:i386) %}
  record Stats,
    # collections : UInt64,
    # bytes_found : Int64,
    heap_size : UInt32,
    free_bytes : UInt32,
    unmapped_bytes : UInt32,
    bytes_since_gc : UInt32,
    total_bytes : UInt32
{% else %}
  record Stats,
    # collections : UInt64,
    # bytes_found : Int64,
    heap_size : UInt64,
    free_bytes : UInt64,
    unmapped_bytes : UInt64,
    bytes_since_gc : UInt64,
    total_bytes : UInt64
{% end %}
  record ProfStats,
    heap_size : UInt64,
    free_bytes : UInt64,
    unmapped_bytes : UInt64,
    bytes_since_gc : UInt64,
    bytes_before_gc : UInt64,
    non_gc_bytes : UInt64,
    gc_no : UInt64,
    markers_m1 : UInt64,
    bytes_reclaimed_since_gc : UInt64,
    reclaimed_bytes_before_gc : UInt64

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
  #
  # WARNING: Memory allocated using `Pointer.malloc` must be reallocated using
  # `Pointer#realloc` instead.
  def self.realloc(pointer : T*, size : Int) : T* forall T
    realloc(pointer.as(Void*), LibC::SizeT.new(size)).as(T*)
  end
end

{% if flag?(:gc_none) || flag?(:wasm32) %}
  require "gc/none"
{% else %}
  require "gc/boehm"
{% end %}
