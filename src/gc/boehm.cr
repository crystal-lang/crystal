@[Link("pthread")]
{% if flag?(:freebsd) %}
  @[Link("gc-threaded")]
{% else %}
  @[Link("gc")]
{% end %}

lib LibGC
  alias Int = LibC::Int
  alias SizeT = LibC::SizeT
  alias Word = LibC::ULong

  fun init = GC_init
  fun malloc = GC_malloc(size : SizeT) : Void*
  fun malloc_atomic = GC_malloc_atomic(size : SizeT) : Void*
  fun realloc = GC_realloc(ptr : Void*, size : SizeT) : Void*
  fun free = GC_free(ptr : Void*)
  fun collect_a_little = GC_collect_a_little : Int
  fun collect = GC_gcollect
  fun add_roots = GC_add_roots(low : Void*, high : Void*)
  fun enable = GC_enable
  fun disable = GC_disable
  fun is_disabled = GC_is_disabled : Int
  fun set_handle_fork = GC_set_handle_fork(value : Int)

  fun base = GC_base(displaced_pointer : Void*) : Void*
  fun is_heap_ptr = GC_is_heap_ptr(pointer : Void*) : Int
  fun general_register_disappearing_link = GC_general_register_disappearing_link(link : Void**, obj : Void*) : Int

  type Finalizer = Void*, Void* ->
  fun register_finalizer = GC_register_finalizer(obj : Void*, fn : Finalizer, cd : Void*, ofn : Finalizer*, ocd : Void**)
  fun register_finalizer_ignore_self = GC_register_finalizer_ignore_self(obj : Void*, fn : Finalizer, cd : Void*, ofn : Finalizer*, ocd : Void**)
  fun invoke_finalizers = GC_invoke_finalizers : Int

  fun get_heap_usage_safe = GC_get_heap_usage_safe(heap_size : Word*, free_bytes : Word*, unmapped_bytes : Word*, bytes_since_gc : Word*, total_bytes : Word*)
  fun set_max_heap_size = GC_set_max_heap_size(Word)

  fun get_start_callback = GC_get_start_callback : Void*
  fun set_start_callback = GC_set_start_callback(callback : ->)

  fun set_push_other_roots = GC_set_push_other_roots(proc : ->)
  fun get_push_other_roots = GC_get_push_other_roots : ->

  fun push_all_eager = GC_push_all_eager(bottom : Void*, top : Void*)

  $stackbottom = GC_stackbottom : Void*

  fun set_on_collection_event = GC_set_on_collection_event(cb : ->)

  $gc_no = GC_gc_no : LibC::ULong
  $bytes_found = GC_bytes_found : LibC::Long
  # GC_on_collection_event isn't exported.  Can't collect totals without it.
  # bytes_allocd, heap_size, unmapped_bytes are macros

  fun size = GC_size(addr : Void*) : LibC::SizeT

  # Boehm GC requires to use GC_pthread_create and GC_pthread_join instead of pthread_create and pthread_join
  fun pthread_create = GC_pthread_create(thread : LibC::PthreadT*, attr : Void*, start : Void* ->, arg : Void*) : LibC::Int
  fun pthread_join = GC_pthread_join(thread : LibC::PthreadT, value : Void**) : LibC::Int
  fun pthread_detach = GC_pthread_detach(thread : LibC::PthreadT) : LibC::Int
end

# :nodoc:
fun __crystal_malloc(size : UInt32) : Void*
  LibGC.malloc(size)
end

# :nodoc:
fun __crystal_malloc_atomic(size : UInt32) : Void*
  LibGC.malloc_atomic(size)
end

# :nodoc:
fun __crystal_realloc(ptr : Void*, size : UInt32) : Void*
  LibGC.realloc(ptr, size)
end

# :nodoc:
fun __crystal_malloc64(size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  LibGC.malloc(size)
end

# :nodoc:
fun __crystal_malloc_atomic64(size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  LibGC.malloc_atomic(size)
end

# :nodoc:
fun __crystal_realloc64(ptr : Void*, size : UInt64) : Void*
  {% if flag?(:bits32) %}
    if size > UInt32::MAX
      raise ArgumentError.new("Given size is bigger than UInt32::MAX")
    end
  {% end %}

  LibGC.realloc(ptr, size)
end

module GC
  def self.init
    LibGC.set_handle_fork(1)
    LibGC.init
  end

  def self.collect
    LibGC.collect
  end

  def self.enable
    unless LibGC.is_disabled != 0
      raise "GC is not disabled"
    end

    LibGC.enable
  end

  def self.disable
    LibGC.disable
  end

  def self.free(pointer : Void*)
    LibGC.free(pointer)
  end

  def self.add_finalizer(object : Reference)
    add_finalizer_impl(object)
  end

  def self.add_finalizer(object)
    # Nothing
  end

  private def self.add_finalizer_impl(object : T) forall T
    LibGC.register_finalizer_ignore_self(object.as(Void*),
      ->(obj, data) { obj.as(T).finalize },
      nil, nil, nil)
    nil
  end

  def self.add_root(object : Reference)
    roots = @@roots ||= [] of Pointer(Void)
    roots << Pointer(Void).new(object.object_id)
  end

  def self.register_disappearing_link(pointer : Void**)
    base = LibGC.base(pointer.value)
    LibGC.general_register_disappearing_link(pointer, base)
  end

  def self.is_heap_ptr(pointer : Void*)
    LibGC.is_heap_ptr(pointer) != 0
  end

  record Stats,
    # collections : LibC::ULong,
    # bytes_found : LibC::Long,
    heap_size : LibC::ULong,
    free_bytes : LibC::ULong,
    unmapped_bytes : LibC::ULong,
    bytes_since_gc : LibC::ULong,
    total_bytes : LibC::ULong

  def self.stats
    LibGC.get_heap_usage_safe(out heap_size, out free_bytes, out unmapped_bytes, out bytes_since_gc, out total_bytes)
    # collections = LibGC.gc_no - 1
    # bytes_found = LibGC.bytes_found

    Stats.new(
      # collections: collections,
      # bytes_found: bytes_found,
      heap_size: heap_size,
      free_bytes: free_bytes,
      unmapped_bytes: unmapped_bytes,
      bytes_since_gc: bytes_since_gc,
      total_bytes: total_bytes
    )
  end
end
