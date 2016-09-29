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

    ret = LibGC.pthread_create(out th, nil, ->(data) {
      (data.as(Thread)).start
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
  end

  def finalize
    LibGC.pthread_detach(@th.not_nil!) unless @detached
  end

  def join
    if LibGC.pthread_join(@th.not_nil!, out _ret) != 0
      raise Errno.new("pthread_join")
    end
    @detached = true

    if exception = @exception
      raise exception
    end
  end

  # All threads, so the GC can see them (GC doesn't scan thread locals)
  @@threads = Set(Thread).new

  {% if !flag?(:openbsd) %}
    @[ThreadLocal]
  {% end %}
  @@current = new

  def self.current
    {% if flag?(:openbsd) %}
      pthread_self_id = LibC.pthread_self().as(UInt64*).address
      
      @@threads.each do |thread|
        if LibC.pthread_main_np() == 1
          return thread
        else
          return thread if thread.pthread_id == pthread_self_id
        end
      end
    {% end %}

    @@current
  end

  {% if flag?(:openbsd) %}
    protected def pthread_id
      @th ? @th.not_nil!.address.as(UInt64) : nil
    end
  {% end %}
  
  protected def start
    @@current = self
    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
    end
  end
end
