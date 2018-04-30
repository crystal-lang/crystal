require "c/pthread"
require "./thread/*"

# :nodoc:
class Thread
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  @th : LibC::PthreadT?
  @exception : Exception?
  @detached = false

  property current_fiber

  def initialize(&@func : ->)
    @current_fiber = uninitialized Fiber
    @@threads << self
    @th = th = uninitialized LibC::PthreadT

    ret = GC.pthread_create(pointerof(th), Pointer(LibC::PthreadAttrT).null, ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))
    @th = th

    if ret != 0
      raise Errno.new("pthread_create")
    end
  end

  def initialize
    @current_fiber = uninitialized Fiber
    @func = ->{}
    @@threads << self
    @th = LibC.pthread_self
  end

  def finalize
    GC.pthread_detach(@th.not_nil!) unless @detached
  end

  def join
    GC.pthread_join(@th.not_nil!)
    @detached = true

    if exception = @exception
      raise exception
    end
  end

  # All threads, so the GC can see them (GC doesn't scan thread locals)
  # and we can find the current thread on platforms that don't support
  # thread local storage (eg: OpenBSD)
  @@threads = Set(Thread).new

  {% if flag?(:openbsd) %}
    @@main = new

    def self.current : Thread
      if LibC.pthread_main_np == 1
        return @@main
      end

      current_thread_id = LibC.pthread_self

      current_thread = @@threads.find do |thread|
        LibC.pthread_equal(thread.id, current_thread_id) != 0
      end

      raise "Error: failed to find current thread" unless current_thread
      current_thread
    end

    protected def id
      @th.not_nil!
    end
  {% else %}
    @[ThreadLocal]
    @@current = new

    def self.current
      @@current
    end
  {% end %}

  protected def start
    {% unless flag?(:openbsd) %}
    @@current = self
    {% end %}
    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
    end
  end
end
