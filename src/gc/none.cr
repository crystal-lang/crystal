{% if flag?(:win32) %}
  require "c/process"
{% end %}

module GC
  def self.init
  end

  # :nodoc:
  def self.malloc(size : LibC::SizeT) : Void*
    LibC.malloc(size)
  end

  # :nodoc:
  def self.malloc_atomic(size : LibC::SizeT) : Void*
    LibC.malloc(size)
  end

  # :nodoc:
  def self.realloc(pointer : Void*, size : LibC::SizeT) : Void*
    LibC.realloc(pointer, size)
  end

  def self.collect
  end

  def self.enable
  end

  def self.disable
  end

  def self.free(pointer : Void*) : Nil
    LibC.free(pointer)
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
    def self.pthread_join(thread : LibC::PthreadT) : Void*
      ret = LibC.pthread_join(thread, out value)
      raise RuntimeError.from_errno("pthread_join") unless ret == 0
      value
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
end
