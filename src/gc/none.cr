{% if flag?(:win32) %}
  require "c/process"
  require "c/heapapi"
{% end %}
require "crystal/tracing"

module GC
  def self.init
    Crystal::System::Thread.init_suspend_resume
  end

  # :nodoc:
  def self.malloc(size : LibC::SizeT) : Void*
    Crystal.trace :gc, "malloc", size: size

    {% if flag?(:win32) %}
      LibC.HeapAlloc(LibC.GetProcessHeap, LibC::HEAP_ZERO_MEMORY, size)
    {% else %}
      # libc malloc is not guaranteed to return cleared memory, so we need to
      # explicitly clear it. Ref: https://github.com/crystal-lang/crystal/issues/14678
      LibC.malloc(size).tap(&.clear)
    {% end %}
  end

  # :nodoc:
  def self.malloc_atomic(size : LibC::SizeT) : Void*
    Crystal.trace :gc, "malloc", size: size, atomic: 1

    {% if flag?(:win32) %}
      LibC.HeapAlloc(LibC.GetProcessHeap, 0, size)
    {% else %}
      LibC.malloc(size)
    {% end %}
  end

  # :nodoc:
  def self.realloc(pointer : Void*, size : LibC::SizeT) : Void*
    Crystal.trace :gc, "realloc", size: size

    {% if flag?(:win32) %}
      # realloc with a null pointer should behave like plain malloc, but Win32
      # doesn't do that
      if pointer
        LibC.HeapReAlloc(LibC.GetProcessHeap, LibC::HEAP_ZERO_MEMORY, pointer, size)
      else
        LibC.HeapAlloc(LibC.GetProcessHeap, LibC::HEAP_ZERO_MEMORY, size)
      end
    {% else %}
      LibC.realloc(pointer, size)
    {% end %}
  end

  def self.collect
  end

  def self.enable
  end

  def self.disable
  end

  def self.free(pointer : Void*) : Nil
    Crystal.trace :gc, "free"

    {% if flag?(:win32) %}
      LibC.HeapFree(LibC.GetProcessHeap, 0, pointer)
    {% else %}
      LibC.free(pointer)
    {% end %}
  end

  def self.is_heap_ptr(pointer : Void*) : Bool
    false
  end

  def self.add_finalizer(object)
  end

  def self.register_disappearing_link(pointer : Void**)
  end

  def self.stats : GC::Stats
    Stats.new(
      # collections: 0,
      # bytes_found: 0,
      heap_size: 0,
      free_bytes: 0,
      unmapped_bytes: 0,
      bytes_since_gc: 0,
      total_bytes: 0)
  end

  def self.prof_stats
    ProfStats.new(
      heap_size: 0,
      free_bytes: 0,
      unmapped_bytes: 0,
      bytes_since_gc: 0,
      bytes_before_gc: 0,
      non_gc_bytes: 0,
      gc_no: 0,
      markers_m1: 0,
      bytes_reclaimed_since_gc: 0,
      reclaimed_bytes_before_gc: 0,
      expl_freed_bytes_since_gc: 0,
      obtained_from_os_bytes: 0)
  end

  {% if flag?(:win32) %}
    # :nodoc:
    def self.beginthreadex(security : Void*, stack_size : LibC::UInt, start_address : Void* -> LibC::UInt, arglist : Void*, initflag : LibC::UInt, thrdaddr : LibC::UInt*) : LibC::HANDLE
      ret = LibC._beginthreadex(security, stack_size, start_address, arglist, initflag, thrdaddr)
      raise RuntimeError.from_errno("_beginthreadex") if ret.null?
      ret.as(LibC::HANDLE)
    end
  {% elsif !flag?(:wasm32) %}
    # :nodoc:
    def self.pthread_create(thread : LibC::PthreadT*, attr : LibC::PthreadAttrT*, start : Void* -> Void*, arg : Void*)
      LibC.pthread_create(thread, attr, start, arg)
    end

    # :nodoc:
    def self.pthread_join(thread : LibC::PthreadT)
      LibC.pthread_join(thread, nil)
    end

    # :nodoc:
    def self.pthread_detach(thread : LibC::PthreadT)
      LibC.pthread_detach(thread)
    end
  {% end %}

  # :nodoc:
  def self.current_thread_stack_bottom : {Void*, Void*}
    {Pointer(Void).null, Pointer(Void).null}
  end

  # :nodoc:
  {% if flag?(:preview_mt) %}
    def self.set_stackbottom(thread : Thread, stack_bottom : Void*)
      # NOTE we could store stack_bottom per thread,
      #      and return it in `#current_thread_stack_bottom`,
      #      but there is no actual use for that.
    end
  {% else %}
    def self.set_stackbottom(stack_bottom : Void*)
    end
  {% end %}

  # :nodoc:
  def self.lock_read
  end

  # :nodoc:
  def self.unlock_read
  end

  # :nodoc:
  def self.lock_write
  end

  # :nodoc:
  def self.unlock_write
  end

  # :nodoc:
  def self.push_stack(stack_top, stack_bottom)
  end

  # Stop and start the world.
  #
  # This isn't a GC-safe stop-the-world implementation (it may allocate objects
  # while stopping the world), but the guarantees are enough for the purpose of
  # gc_none. It could be GC-safe if Thread::LinkedList(T) became a struct, and
  # Thread::Mutex either became a struct or provide low level abstraction
  # methods that directly interact with syscalls (without allocating).
  #
  # Thread safety is guaranteed by the mutex in Thread::LinkedList: either a
  # thread is starting and hasn't added itself to the list (it will block until
  # it can acquire the lock), or is currently adding itself (the current thread
  # will block until it can acquire the lock).
  #
  # In both cases there can't be a deadlock since we won't suspend another
  # thread until it has successfully added (or removed) itself to (from) the
  # linked list and released the lock, and the other thread won't progress until
  # it can add (or remove) itself from the list.
  #
  # Finally, we lock the mutex and keep it locked until we resume the world, so
  # any thread waiting on the mutex will only be resumed when the world is
  # resumed.

  # :nodoc:
  def self.stop_world : Nil
    current_thread = Thread.current

    # grab the lock (and keep it until the world is restarted)
    Thread.lock

    # tell all threads to stop (async)
    Thread.unsafe_each do |thread|
      thread.suspend unless thread == current_thread
    end

    # wait for all threads to have stopped
    Thread.unsafe_each do |thread|
      thread.wait_suspended unless thread == current_thread
    end
  end

  # :nodoc:
  def self.start_world : Nil
    current_thread = Thread.current

    # tell all threads to resume
    Thread.unsafe_each do |thread|
      thread.resume unless thread == current_thread
    end

    # finally, we can release the lock
    Thread.unlock
  end
end
