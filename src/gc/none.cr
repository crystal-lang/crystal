{% unless flag?(:win32) %}
  @[Link("pthread")]
  lib LibC
  end
{% end %}

module GC
  def self.init
  end

  # :nodoc:
  def self.malloc(size : LibC::SizeT)
    LibC.malloc(size)
  end

  # :nodoc:
  def self.malloc_atomic(size : LibC::SizeT)
    LibC.malloc(size)
  end

  # :nodoc:
  def self.realloc(pointer : Void*, size : LibC::SizeT)
    LibC.realloc(pointer, size)
  end

  def self.collect
  end

  def self.enable
  end

  def self.disable
  end

  def self.free(pointer : Void*)
    LibC.free(pointer)
  end

  def self.is_heap_ptr(pointer : Void*)
    false
  end

  def self.add_finalizer(object)
  end

  def self.stats
    zero = LibC::ULong.new(0)
    Stats.new(zero, zero, zero, zero, zero)
  end

  {% unless flag?(:win32) %}
    # :nodoc:
    def self.pthread_create(thread : LibC::PthreadT*, attr : LibC::PthreadAttrT*, start : Void* -> Void*, arg : Void*)
      LibC.pthread_create(thread, attr, start, arg)
    end

    # :nodoc:
    def self.pthread_join(thread : LibC::PthreadT) : Void*
      ret = LibC.pthread_join(thread, out value)
      raise Errno.new("pthread_join") unless ret == 0
      value
    end

    # :nodoc:
    def self.pthread_detach(thread : LibC::PthreadT)
      LibC.pthread_detach(thread)
    end
  {% end %}

  @@stack_bottom = Pointer(Void).null

  # :nodoc:
  def self.current_thread_stack_bottom
    {Pointer(Void).null, @@stack_bottom}
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
