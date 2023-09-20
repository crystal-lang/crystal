{% if flag?(:preview_mt) %}
  require "crystal/rw_lock"
{% end %}

# MUSL: On musl systems, libpthread is empty. The entire library is already included in libc.
# The empty library is only available for POSIX compatibility. We don't need to link it.
#
# Darwin: `libpthread` is provided as part of `libsystem`. There's no reason to link it explicitly.
#
# Interpreter: Starting with glibc 2.34, `pthread` is integrated into `libc`
# and may not even be available as a separate shared library.
# There's always a static library for compiled mode, but `Crystal::Loader` does not support
# static libraries. So we just skip `pthread` entirely. The symbols are still
# available in the interpreter because they are loaded in the compiler.
#
# OTHERS: On other systems, we add the linker annotation here to make sure libpthread is loaded
# before libgc which looks up symbols from libpthread.
{% unless flag?(:win32) || flag?(:musl) || flag?(:darwin) || flag?(:android) || (flag?(:interpreted) && flag?(:gnu)) %}
  @[Link("pthread")]
{% end %}

{% if flag?(:freebsd) || flag?(:dragonfly) %}
  @[Link("gc-threaded")]
{% else %}
  @[Link("gc")]
{% end %}

lib LibGC
  alias Int = LibC::Int
  alias SizeT = LibC::SizeT
  {% if flag?(:win32) && flag?(:bits64) %}
    alias Word = LibC::ULongLong
    alias SignedWord = LibC::LongLong
  {% else %}
    alias Word = LibC::ULong
    alias SignedWord = LibC::Long
  {% end %}

  struct StackBase
    mem_base : Void*
    # reg_base : Void* should be used also for IA-64 when/if supported
  end

  alias ThreadHandle = Void*

  struct ProfStats
    heap_size : Word
    free_bytes : Word
    unmapped_bytes : Word
    bytes_since_gc : Word
    bytes_before_gc : Word
    non_gc_bytes : Word
    gc_no : Word
    markers_m1 : Word
    bytes_reclaimed_since_gc : Word
    reclaimed_bytes_before_gc : Word
    expl_freed_bytes_since_gc : Word
    obtained_from_os_bytes : Word
  end

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

  alias Finalizer = Void*, Void* ->
  fun register_finalizer = GC_register_finalizer(obj : Void*, fn : Finalizer, cd : Void*, ofn : Finalizer*, ocd : Void**)
  fun register_finalizer_ignore_self = GC_register_finalizer_ignore_self(obj : Void*, fn : Finalizer, cd : Void*, ofn : Finalizer*, ocd : Void**)
  fun invoke_finalizers = GC_invoke_finalizers : Int

  fun get_heap_usage_safe = GC_get_heap_usage_safe(heap_size : Word*, free_bytes : Word*, unmapped_bytes : Word*, bytes_since_gc : Word*, total_bytes : Word*)
  fun set_max_heap_size = GC_set_max_heap_size(Word)

  fun get_prof_stats = GC_get_prof_stats(stats : ProfStats*, size : SizeT)

  fun get_start_callback = GC_get_start_callback : Void*
  fun set_start_callback = GC_set_start_callback(callback : ->)

  fun set_push_other_roots = GC_set_push_other_roots(proc : ->)
  fun get_push_other_roots = GC_get_push_other_roots : ->

  fun push_all_eager = GC_push_all_eager(bottom : Void*, top : Void*)

  {% if flag?(:preview_mt) || flag?(:win32) %}
    fun get_my_stackbottom = GC_get_my_stackbottom(sb : StackBase*) : ThreadHandle
    fun set_stackbottom = GC_set_stackbottom(th : ThreadHandle, sb : StackBase*) : ThreadHandle
  {% else %}
    $stackbottom = GC_stackbottom : Void*
  {% end %}

  fun set_on_collection_event = GC_set_on_collection_event(cb : ->)

  $gc_no = GC_gc_no : Word
  $bytes_found = GC_bytes_found : SignedWord
  # GC_on_collection_event isn't exported.  Can't collect totals without it.
  # bytes_allocd, heap_size, unmapped_bytes are macros

  fun size = GC_size(addr : Void*) : LibC::SizeT

  # Boehm GC requires to use its own thread manipulation routines instead of pthread's or Win32's
  {% if flag?(:win32) %}
    fun beginthreadex = GC_beginthreadex(security : Void*, stack_size : LibC::UInt, start_address : Void* -> LibC::UInt,
                                         arglist : Void*, initflag : LibC::UInt, thrdaddr : LibC::UInt*) : Void*
  {% elsif !flag?(:wasm32) %}
    fun pthread_create = GC_pthread_create(thread : LibC::PthreadT*, attr : LibC::PthreadAttrT*, start : Void* -> Void*, arg : Void*) : LibC::Int
    fun pthread_join = GC_pthread_join(thread : LibC::PthreadT, value : Void**) : LibC::Int
    fun pthread_detach = GC_pthread_detach(thread : LibC::PthreadT) : LibC::Int
  {% end %}

  alias WarnProc = LibC::Char*, Word ->
  fun set_warn_proc = GC_set_warn_proc(WarnProc)
  $warn_proc = GC_current_warn_proc : WarnProc
end

module GC
  {% if flag?(:preview_mt) %}
    @@lock = Crystal::RWLock.new
  {% end %}

  # :nodoc:
  def self.malloc(size : LibC::SizeT) : Void*
    LibGC.malloc(size)
  end

  # :nodoc:
  def self.malloc_atomic(size : LibC::SizeT) : Void*
    LibGC.malloc_atomic(size)
  end

  # :nodoc:
  def self.realloc(ptr : Void*, size : LibC::SizeT) : Void*
    LibGC.realloc(ptr, size)
  end

  def self.init : Nil
    {% unless flag?(:win32) %}
      LibGC.set_handle_fork(1)
    {% end %}
    LibGC.init

    LibGC.set_start_callback ->do
      GC.lock_write
    end
    # By default the GC warns on big allocations/reallocations. This
    # is of limited use and pollutes program output with warnings.
    LibGC.set_warn_proc ->(msg, v) do
      start = "GC Warning: Repeated allocation of very large block"
      # This implements `String#starts_with?` without allocating a `String` (#11728)
      format_string = Slice.new(msg, Math.min(LibC.strlen(msg), start.bytesize))
      unless format_string == start.to_slice
        Crystal::System.print_error msg, v
      end
    end
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

  def self.free(pointer : Void*) : Nil
    LibGC.free(pointer)
  end

  def self.add_finalizer(object : Reference) : Nil
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

  def self.stats
    LibGC.get_heap_usage_safe(out heap_size, out free_bytes, out unmapped_bytes, out bytes_since_gc, out total_bytes)
    # collections = LibGC.gc_no - 1
    # bytes_found = LibGC.bytes_found

    Stats.new(
      # collections: collections,
      # bytes_found: bytes_found,
      heap_size: heap_size.to_u64!,
      free_bytes: free_bytes.to_u64!,
      unmapped_bytes: unmapped_bytes.to_u64!,
      bytes_since_gc: bytes_since_gc.to_u64!,
      total_bytes: total_bytes.to_u64!
    )
  end

  def self.prof_stats
    LibGC.get_prof_stats(out stats, sizeof(LibGC::ProfStats))

    ProfStats.new(
      heap_size: stats.heap_size.to_u64!,
      free_bytes: stats.free_bytes.to_u64!,
      unmapped_bytes: stats.unmapped_bytes.to_u64!,
      bytes_since_gc: stats.bytes_since_gc.to_u64!,
      bytes_before_gc: stats.bytes_before_gc.to_u64!,
      non_gc_bytes: stats.non_gc_bytes.to_u64!,
      gc_no: stats.gc_no.to_u64!,
      markers_m1: stats.markers_m1.to_u64!,
      bytes_reclaimed_since_gc: stats.bytes_reclaimed_since_gc.to_u64!,
      reclaimed_bytes_before_gc: stats.reclaimed_bytes_before_gc.to_u64!,
      expl_freed_bytes_since_gc: stats.expl_freed_bytes_since_gc.to_u64!,
      obtained_from_os_bytes: stats.obtained_from_os_bytes.to_u64!)
  end

  {% if flag?(:win32) %}
    # :nodoc:
    def self.beginthreadex(security : Void*, stack_size : LibC::UInt, start_address : Void* -> LibC::UInt, arglist : Void*, initflag : LibC::UInt, thrdaddr : LibC::UInt*) : LibC::HANDLE
      ret = LibGC.beginthreadex(security, stack_size, start_address, arglist, initflag, thrdaddr)
      raise RuntimeError.from_errno("GC_beginthreadex") if ret.null?
      ret.as(LibC::HANDLE)
    end
  {% else %}
    # :nodoc:
    def self.pthread_create(thread : LibC::PthreadT*, attr : LibC::PthreadAttrT*, start : Void* -> Void*, arg : Void*)
      LibGC.pthread_create(thread, attr, start, arg)
    end

    # :nodoc:
    def self.pthread_join(thread : LibC::PthreadT) : Void*
      ret = LibGC.pthread_join(thread, out value)
      raise RuntimeError.from_os_error("pthread_join", Errno.new(ret)) unless ret == 0
      value
    end

    # :nodoc:
    def self.pthread_detach(thread : LibC::PthreadT)
      LibGC.pthread_detach(thread)
    end
  {% end %}

  # :nodoc:
  def self.current_thread_stack_bottom
    {% if flag?(:preview_mt) || flag?(:win32) %}
      th = LibGC.get_my_stackbottom(out sb)
      {th, sb.mem_base}
    {% else %}
      {Pointer(Void).null, LibGC.stackbottom}
    {% end %}
  end

  # :nodoc:
  {% if flag?(:preview_mt) %}
    def self.set_stackbottom(thread_handle : Void*, stack_bottom : Void*)
      sb = LibGC::StackBase.new
      sb.mem_base = stack_bottom
      LibGC.set_stackbottom(thread_handle, pointerof(sb))
    end
  {% elsif flag?(:win32) %}
    # this is necessary because Boehm GC does _not_ use `GC_stackbottom` on
    # Windows when pushing all threads' stacks; instead `GC_set_stackbottom`
    # must be used to associate the new bottom with the running thread
    def self.set_stackbottom(stack_bottom : Void*)
      sb = LibGC::StackBase.new
      sb.mem_base = stack_bottom
      # `nil` represents the current thread (i.e. the only one)
      LibGC.set_stackbottom(nil, pointerof(sb))
    end
  {% else %}
    def self.set_stackbottom(stack_bottom : Void*)
      LibGC.stackbottom = stack_bottom
    end
  {% end %}

  # :nodoc:
  def self.lock_read
    {% if flag?(:preview_mt) %}
      @@lock.read_lock
    {% end %}
  end

  # :nodoc:
  def self.unlock_read
    {% if flag?(:preview_mt) %}
      @@lock.read_unlock
    {% end %}
  end

  # :nodoc:
  def self.lock_write
    {% if flag?(:preview_mt) %}
      @@lock.write_lock
    {% end %}
  end

  # :nodoc:
  def self.unlock_write
    {% if flag?(:preview_mt) %}
      @@lock.write_unlock
    {% end %}
  end

  # :nodoc:
  def self.push_stack(stack_top, stack_bottom) : Nil
    LibGC.push_all_eager(stack_top, stack_bottom)
  end

  # :nodoc:
  def self.before_collect(&block) : Nil
    @@curr_push_other_roots = block
    @@prev_push_other_roots = LibGC.get_push_other_roots

    LibGC.set_push_other_roots ->do
      @@curr_push_other_roots.try(&.call)
      @@prev_push_other_roots.try(&.call)
    end
  end

  # pushes the stack of pending fibers when the GC wants to collect memory:
  {% unless flag?(:interpreted) %}
    GC.before_collect do
      Fiber.unsafe_each do |fiber|
        fiber.push_gc_roots unless fiber.running?
      end

      {% if flag?(:preview_mt) %}
        Thread.unsafe_each do |thread|
          if scheduler = thread.@scheduler
            fiber = scheduler.@current
            GC.set_stackbottom(thread.gc_thread_handler, fiber.@stack_bottom)
          end
        end
      {% end %}

      GC.unlock_write
    end
  {% end %}
end
